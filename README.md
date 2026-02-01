# EventID - Regulatory Compliance Event System

**UUIDv7 Event Bus | Version 1**

Production-grade regulatory compliance event system with automated workspace monitoring for GRC platforms.

## 🎯 Overview

EventID is a bidirectional event bus that connects your compliance platforms (Claude the Scraper, Assure Code, Assure Scan, and Assure Review) through a central Kafka-based event infrastructure. Every action in each platform becomes an immutable event, creating a complete audit trail for compliance workflows.

### Core Capabilities

- **🔐 OAuth 2.0 Authentication**: Machine-to-machine auth with RSA-256 signed JWTs
- **📊 Event Streaming**: Apache Kafka for reliable, ordered event delivery
- **💾 Immutable Audit Log**: PostgreSQL-backed permanent event storage
- **🤖 Intelligent Automation**: Workspace matching with automated spec regeneration
- **🔄 Bidirectional Integration**: Platforms both send and receive events
- **📈 Full Observability**: Prometheus metrics + Grafana dashboard

## ⚙️ Setup Instructions

1.  **Prerequisites**
    -   Go 1.21+
    -   Docker
    -   Docker Compose

2.  **Clone the Repository**

    ```bash
    git clone <repository_url>
    cd eventid-system
    ```

3.  **Configuration**
    -   Copy `.env.example` to `.env` and fill in the required environment variables.

        ```bash
        cp .env.example .env
        nano .env
        ```

4.  **Start the System**

    ```bash
    make run
    ```

    This command starts all services using Docker Compose.

5.  **Access the Services**
    -   API Server: `http://localhost:8081`
    -   Auth Server: `http://localhost:8082`
    -   Kafka UI: `http://localhost:8080`
    -   Prometheus: `http://localhost:9090`
    -   Grafana: `http://localhost:3001` (admin/admin)

## 🚀 Usage

1.  **Publishing Events**
    -   Use the API server to publish events to the Kafka topic.
    -   Authenticate using OAuth 2.0.

2.  **Consuming Events**
    -   The event consumer automatically consumes events from the Kafka topic and stores them in the PostgreSQL database.

3.  **Workspace Monitoring**
    -   The workspace monitor automatically matches events to workspaces and triggers actions based on the configuration.

## 🧪 Testing

1.  **Run Tests**

    ```bash
    make test
    ```

2.  **Send Test Event**

    ```bash
    make test-event
    ```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
