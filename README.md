# gridappsd-docker

## Requirements
  - git
  - Docker version 17.12 or higher
  - Docker Compose (either `docker compose` or `docker-compose`)

## Install Docker

See [DOCKER_INSTALL.md](DOCKER_INSTALL.md) for detailed installation instructions for:
- Ubuntu / Debian
- Fedora / RHEL / CentOS
- macOS
- Windows

## Clone or download the repository
```bash
git clone https://github.com/GRIDAPPSD/gridappsd-docker
cd gridappsd-docker
```

## Check Available Versions

To see available GridAPPS-D versions on Docker Hub:
```bash
./get-versions.sh           # Show release versions (v2023.07.0 format)
./get-versions.sh -a        # Show all tags including develop, latest
./get-versions.sh -n 20     # Show more results
```

## Start the docker container services
```
./run.sh
```
The run.sh script does the following:
 - Downloads the mysql dump file
 - Downloads the blazegraph data
 - Starts the docker containers
 - Ingests the blazegraph data
 - Starts GridAPPS-D automatically

### run.sh Options

| Option | Description |
|--------|-------------|
| `-d` | Enable debug output |
| `-n` | No auto-start; drop into container shell instead |
| `-p` | Pull updated containers |
| `-r [ip]` | Use remote IP address for viz (uses external IP if not specified) |
| `-t tag` | Specify GridAPPS-D docker tag (e.g., `-t v2023.07.0`) |

### Examples
```bash
./run.sh                    # Start with auto-start (default)
./run.sh -n                 # Start and drop into container shell
./run.sh -t develop         # Use develop tag
./run.sh -t v2023.07.0      # Use specific version
```

## Available Endpoints

Once running, GridAPPS-D is available at:

| Service | URL/Address |
|---------|-------------|
| Web UI | http://localhost:8080/ |
| Blazegraph | http://localhost:8889/bigdata/ |
| STOMP | tcp://localhost:61613 |
| WebSocket | ws://localhost:61614 |
| OpenWire | tcp://localhost:61616 |

When the observability overlay is active, Grafana and supporting services are also reachable. See [Observability Stack](#observability-stack) in the docker-compose.d section below.

## Connecting to the Container

```bash
docker exec -it gridappsd /bin/bash
```

## Viewing Logs

```bash
docker logs -f gridappsd
```

## Stopping the containers

```bash
./stop.sh           # Stop containers
./stop.sh -c        # Stop and remove containers, dump files, and databases
./stop.sh -w        # Stop and remove containers and databases, keep dump files
```

> **Note:** There is also a `remove_all_containers.sh` script, but be aware that it removes **ALL** Docker containers and unused networks on your system, not just GridAPPS-D. Use `./stop.sh -c` to remove only GridAPPS-D containers.

## Restarting the containers
```
./run.sh
```

## Next Steps
  - Add applications/services to the containers (see how <https://github.com/GRIDAPPSD/gridappsd-sample-app>)

---

## docker-compose.d Directory

The `docker-compose.d/` directory allows you to extend the base docker-compose configuration with additional services. Any `.yml` file in this directory is automatically included when running `./run.sh`.

### How It Works

1. The `run.sh` script scans `docker-compose.d/` for files ending in `.yml`
2. Each `.yml` file is added to the docker-compose command with `-f`
3. Services defined in these files are started alongside the core GridAPPS-D services

### Adding Optional Services

The directory contains `.dist` files as templates for optional services:

| File | Description |
|------|-------------|
| `docker-compose_pyvvo.yml.dist` | PyVVO voltage optimization app |
| `docker-compose_der-dispatch.yml.dist` | DER dispatch service |
| `docker-compose_solar-forecast.yml.dist` | Solar forecasting service |
| `docker-compose_grid-forecasting.yml.dist` | Grid forecasting service |
| `docker-compose_wsu-vvo.yml.dist` | WSU VVO application |
| `docker-compose_wsu-restoration.yml.cplex` | WSU restoration (requires CPLEX) |
| `docker-compose_timescaledb.yml.dst` | TimescaleDB for time-series data |
| `docker-compose-grafana.yml.dist` | Observability stack: Grafana, Prometheus, Loki, Tempo, OTel collector |

To enable an optional service:
```bash
# Copy and rename the template (remove .dist suffix)
cp docker-compose.d/docker-compose_pyvvo.yml.dist docker-compose.d/docker-compose_pyvvo.yml

# Edit as needed
nano docker-compose.d/docker-compose_pyvvo.yml

# Restart to include the new service
./stop.sh
./run.sh
```

### Observability Stack

The `docker-compose-grafana.yml.dist` template adds a full observability stack to the platform.

**What it collects:** metrics via Prometheus, logs via Loki, and distributed traces via Tempo. An OpenTelemetry collector receives data from all three pipelines. The gridappsd JVM is instrumented with the OTel Java agent (v2.25.0), injected at startup via a shared volume, so metrics, logs, and traces flow from the JVM process automatically.

#### Activate and deactivate

The overlay is **off by default**. To enable it, copy the template to a live `.yml` file.

```bash
cp docker-compose.d/docker-compose-grafana.yml.dist docker-compose.d/docker-compose-grafana.yml
```

**Path A: full platform restart via run.sh**
Run `./run.sh` after copying the template. The observability services start alongside the base platform. Use `./stop.sh` to stop everything.

```bash
./run.sh
```

**Path B: additive activation without a restart (observability-up.sh)**
If the base platform is already running, bring observability up alongside it without restarting gridappsd:

```bash
./observability-up.sh
```

To stop observability services only, leaving the base platform running:

```bash
./observability-up.sh --down
```

**Tradeoff:** `run.sh` restarts the entire platform (including gridappsd). `observability-up.sh` does not touch the running base services, making it the right choice when you want to add observability to an already-running session.

#### Endpoints

All observability services bind to `127.0.0.1` (loopback) by default, accessible only from the local machine.

| Service | Default URL | Purpose |
|---------|-------------|---------|
| Grafana | http://localhost:4000/ | Dashboards and log/trace/metric exploration |
| Prometheus | http://localhost:9090/ | Metrics query and scrape status |
| Loki | http://localhost:3100/ | Log query API |
| Tempo | http://localhost:3200/ | Trace query API |
| OTLP gRPC | localhost:4317 | OTel collector ingest (gRPC) |
| OTLP HTTP | http://localhost:4318/ | OTel collector ingest (HTTP) |

**Remote viewing:** use an SSH tunnel to reach these services from a remote workstation. The ports bind to loopback by default and are not directly reachable over the network.

```bash
ssh -L 4000:127.0.0.1:4000 <your-host>
```

Then open `http://localhost:4000/` in your local browser. Repeat the `-L` flag for any other port you need.

**Off-host access:** setting `OBSERVABILITY_BIND_HOST=0.0.0.0` widens the bind to all interfaces. See the security caveats in [Credentials and security](#credentials-and-security) below before doing so.

#### Pre-provisioned dashboards

Three dashboards are provisioned automatically in Grafana:

| Dashboard | Content |
|-----------|---------|
| `application-logs` | Log stream from the gridappsd application via Loki |
| `jvm-metrics` | JVM heap, GC, thread, and CPU metrics via Prometheus |
| `traces-overview` | Distributed trace list and latency histogram via Tempo |

#### Credentials and security

**Grafana admin password:** set `GRAFANA_ADMIN_PASSWORD` in your environment (or in a `.env` file based on `.env.example`) before starting. If the variable is unset or empty, `run.sh` and `observability-up.sh` auto-generate a strong random password and print it in the startup banner so you can log in. The credential gate operates through the launchers (`run.sh` / `observability-up.sh`) only; a direct `docker compose up` without a non-empty `GRAFANA_ADMIN_PASSWORD` bypasses the auto-generate step and can fall back to the Grafana built-in default.

> **Dev-only caveat:** the auto-generated password appears in stdout, scrollback, and any captured logs. This is intentional for local development convenience. For any deployment beyond a local dev machine, set `GRAFANA_ADMIN_PASSWORD` to a value you control and do not share that value in logs.

**Anonymous access:** disabled by default (`GRAFANA_ANONYMOUS_ENABLED=false`). Set `GRAFANA_ANONYMOUS_ENABLED=true` only for dev or demo use on a trusted network.

**Bind host:** the default `127.0.0.1` binding is the safe posture. Setting `OBSERVABILITY_BIND_HOST=0.0.0.0` exposes Prometheus, Loki, Tempo, Grafana, and the OTLP receiver ports off-host; Prometheus, Loki, Tempo, and OTLP have no authentication. Use this setting only on an isolated, trusted network.

See `.env.example` for a full list of observability environment variable names and their defaults.

---

### Auto-Generated Files

The following files may be auto-generated by `run.sh` and are cleaned up by `stop.sh -c`:

- `viz.yml` - Created when using `-r` flag for remote viz configuration
- `no-autostart.yml` - Created when using `-n` flag to disable auto-start

### Creating Custom Services

Create a new `.yml` file in `docker-compose.d/`:

```yaml
services:
  my-custom-app:
    image: my-app:latest
    environment:
      GRIDAPPSD_URI: tcp://gridappsd:61613
    depends_on:
      - gridappsd
```

---

## Advanced Usage

### Using GridAPPS-D on a remote system with a local browser

```bash
./run.sh -r
```

Open your browser to http://remoteip:8080/

### Using a specific version

```bash
# Check available versions
./get-versions.sh

# Run with a specific version
./run.sh -t v2023.07.0
```

### Development mode (no auto-start)

```bash
./run.sh -n
# Inside the container:
./run-gridappsd.sh
```

[Using GridAPPS-D](https://gridappsd.readthedocs.io/en/master/using_gridappsd/index.html)
