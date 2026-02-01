package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/assure-compliance/eventid/pkg/consumer"
	"github.com/assure-compliance/eventid/pkg/schema"
	"github.com/assure-compliance/eventid/pkg/storage"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	eventsConsumed = promauto.NewCounter(prometheus.CounterOpts{
		Name: "regulatory_events_consumed_total",
		Help: "Total number of events consumed from Kafka",
	})
	eventsStored = promauto.NewCounter(prometheus.CounterOpts{
		Name: "regulatory_events_stored_total",
		Help: "Total number of events stored in database",
	})
	errors = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "event_consumer_errors_total",
			Help: "Total number of consumer errors",
		},
		[]string{"error_type"},
	)
)

func main() {
	log.Println("Starting EventID Event Consumer (Audit Trail)...")

	// Load configuration
	config := loadConfig()

	// Initialize event store
	storeCfg := storage.Config{
		Host:     config.DBHost,
		Port:     config.DBPort,
		User:     config.DBUser,
		Password: config.DBPassword,
		Database: config.DBName,
		SSLMode:  config.DBSSLMode,
	}

	store, err := storage.NewEventStore(storeCfg)
	if err != nil {
		log.Fatalf("Failed to create event store: %v", err)
	}
	defer store.Close()

	// Initialize Kafka consumer
	consumerCfg := consumer.Config{
		BootstrapServers: config.KafkaBrokers,
		GroupID:          "eventid-consumer-audit",
		Topics:           []string{config.KafkaTopic},
		AutoOffsetReset:  "earliest", // Process all events from beginning
	}

	eventConsumer, err := consumer.NewEventConsumer(consumerCfg)
	if err != nil {
		log.Fatalf("Failed to create consumer: %v", err)
	}
	defer eventConsumer.Close()

	// Register event handler (stores all events to database)
	eventHandler := func(event interface{}) error {
		eventsConsumed.Inc()

		if err := store.StoreEvent(event); err != nil {
			errors.WithLabelValues("storage").Inc()
			return fmt.Errorf("failed to store event: %w", err)
		}

		eventsStored.Inc()
		return nil
	}

	// Register handler for all event types
	eventTypes := []schema.EventType{
		schema.EventRegulatoryUpdate,
		schema.EventLawFetched,
		schema.EventSpecGenerated,
		schema.EventSpecUpdated,
		schema.EventSpecRequested,
		schema.EventAuditStarted,
		schema.EventAuditCompleted,
		schema.EventViolationFound,
		schema.EventScanRequested,
		schema.EventDocumentUploaded,
		schema.EventComplianceCheck,
		schema.EventGapIdentified,
		schema.EventReviewRequested,
		schema.EventWorkflowStarted,
		schema.EventWorkflowComplete,
		schema.EventValidationStatus,
	}

	for _, eventType := range eventTypes {
		eventConsumer.RegisterHandler(eventType, eventHandler)
	}

	// Start metrics server
	go func() {
		http.Handle("/metrics", promhttp.Handler())
		http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(`{"status":"healthy"}`))
		})

		log.Printf("Metrics server listening on :%s\n", config.MetricsPort)
		if err := http.ListenAndServe(":"+config.MetricsPort, nil); err != nil {
			log.Printf("Metrics server error: %v\n", err)
		}
	}()

	// Handle shutdown gracefully
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigCh
		log.Println("Shutting down event consumer...")
		eventConsumer.Close()
		os.Exit(0)
	}()

	// Start consuming events
	log.Println("Event consumer ready, waiting for events...")
	if err := eventConsumer.Start(); err != nil {
		log.Fatalf("Consumer failed: %v", err)
	}
}

type Config struct {
	KafkaBrokers string
	KafkaTopic   string
	DBHost       string
	DBPort       int
	DBUser       string
	DBPassword   string
	DBName       string
	DBSSLMode    string
	MetricsPort  string
}

func loadConfig() Config {
	return Config{
		KafkaBrokers: getEnv("KAFKA_BROKERS", "localhost:9092"),
		KafkaTopic:   getEnv("KAFKA_TOPIC", "regulatory-events"),
		DBHost:       getEnv("DB_HOST", "localhost"),
		DBPort:       getEnvInt("DB_PORT", 5432),
		DBUser:       getEnv("DB_USER", "eventid"),
		DBPassword:   getEnv("DB_PASSWORD", "password"),
		DBName:       getEnv("DB_NAME", "eventid_events"),
		DBSSLMode:    getEnv("DB_SSLMODE", "disable"),
		MetricsPort:  getEnv("METRICS_PORT", "9090"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		var intVal int
		if _, err := fmt.Sscanf(value, "%d", &intVal); err == nil {
			return intVal
		}
	}
	return defaultValue
}