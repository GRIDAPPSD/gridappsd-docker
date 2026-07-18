# Observability Stack

The `docker-compose-grafana.yml.dist` template adds a full observability stack to the platform.

**What it collects:** metrics via Prometheus, logs via Loki, and distributed traces via Tempo. An OpenTelemetry collector receives data from all three pipelines. The gridappsd JVM is instrumented with the OTel Java agent (v2.25.0), injected at startup via a shared volume, so metrics, logs, and traces flow from the JVM process automatically.

## Activate and deactivate

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

## Endpoints

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

**Off-host access:** setting `OBSERVABILITY_BIND_HOST=0.0.0.0` widens the bind to all interfaces. See [Credentials and security](#credentials-and-security) below before doing so.

## Pre-provisioned dashboards

Three dashboards are provisioned automatically in Grafana:

| Dashboard | Content |
|-----------|---------|
| `application-logs` | Log stream from the gridappsd application via Loki |
| `jvm-metrics` | JVM heap, GC, thread, and CPU metrics via Prometheus |
| `traces-overview` | Distributed trace list and latency histogram via Tempo |

## Credentials and security

**Grafana admin password:** set `GRAFANA_ADMIN_PASSWORD` in your environment (or in a `.env` file based on `.env.example`) before starting. If the variable is unset or empty, `run.sh` and `observability-up.sh` auto-generate a strong random password and print it in the startup banner so you can log in. The credential gate operates through the launchers (`run.sh` / `observability-up.sh`) only; a direct `docker compose up` without a non-empty `GRAFANA_ADMIN_PASSWORD` bypasses the auto-generate step and can fall back to the Grafana built-in default.

> **Dev-only caveat:** the auto-generated password appears in stdout, scrollback, and any captured logs. This is intentional for local development convenience. For any deployment beyond a local dev machine, set `GRAFANA_ADMIN_PASSWORD` to a value you control and do not share that value in logs.

**Anonymous access:** disabled by default (`GRAFANA_ANONYMOUS_ENABLED=false`). Set `GRAFANA_ANONYMOUS_ENABLED=true` only for dev or demo use on a trusted network.

**Bind host:** the default `127.0.0.1` binding is the safe posture. Setting `OBSERVABILITY_BIND_HOST=0.0.0.0` exposes Prometheus, Loki, Tempo, Grafana, and the OTLP receiver ports off-host; Prometheus, Loki, Tempo, and OTLP have no authentication. Use this setting only on an isolated, trusted network.

See `.env.example` for a full list of observability environment variable names and their defaults.
