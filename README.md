# LLMD xKS Preflight Checks

A Python CLI application for running preflight checks on Kubernetes clusters. The tool connects to a Kubernetes cluster and executes a series of validation tests to ensure the cluster is properly configured and ready for use.

## Features

- **Configurable Logging**: Adjustable log levels for debugging and monitoring
- **Flexible Configuration**: Supports command-line arguments, config files, and environment variables
- **Test Framework**: Extensible test execution framework for preflight validations

## Installation

Install the required dependencies:

```bash
pip install configargparse kubernetes
```

## Usage

### Basic Usage

```bash
# Run with default settings (uses default kubeconfig location)
python llmd-xks-checks.py

# With custom log level
python llmd-xks-checks.py --log-level DEBUG

# With custom kubeconfig path
python llmd-xks-checks.py --kube-config /path/to/kubeconfig

# Show help
python llmd-xks-checks.py --help
```

### Configuration File

The application automatically looks for config files in the following locations (in order):
1. `~/.llmd-xks-preflight.conf` (user home directory)
2. `./llmd-xks-preflight.conf` (current directory)
3. `/etc/llmd-xks-preflight.conf` (system-wide)

You can also specify a custom config file:
```bash
python llmd-xks-checks.py --config /path/to/config.conf
```

Example config file:
```ini
log_level = INFO
kube_config = /path/to/kubeconfig
```

### Environment Variables

The application supports environment variables for configuration:

```bash
# Set log level via environment variable
export LLMD_XKS_LOG_LEVEL=DEBUG

# Set kubeconfig path (uses standard KUBECONFIG variable)
export KUBECONFIG=/path/to/kubeconfig

# Run the application
python llmd-xks-checks.py
```

## Configuration Priority

Arguments are resolved in the following priority order (highest to lowest):
1. **Command-line arguments** (highest priority)
2. **Environment variables**
3. **Config file** (from default locations or `--config`)
4. **Default values** (lowest priority)

## Command-Line Arguments

- `-l, --log-level`: Set the log level (choices: DEBUG, INFO, WARNING, ERROR, CRITICAL, default: INFO)
- `-k, --kube-config`: Path to the kubeconfig file (overrides KUBECONFIG environment variable)
- `-c, --config`: Path to a custom config file
- `-u, --cloud-provider`: Specify cloud provider or "auto"
- `-h, --help`: Show help message

## Environment Variables

- `LLMD_XKS_LOG_LEVEL`: Log level (same choices as `--log-level`)
- `KUBECONFIG`: Path to kubeconfig file (standard Kubernetes environment variable)

## Kubernetes Connection

The application connects to Kubernetes clusters using the standard Kubernetes Python client library. It:

- Loads kubeconfig from the default location (`~/.kube/config`) or the path specified via `--kube-config` or `KUBECONFIG`
- Establishes a connection to the cluster using the CoreV1Api
- Exits with an error code if the connection fails
- Logs connection status for debugging

## Test Framework

The application includes a test execution framework. Tests are defined in the `tests` list and executed sequentially. Currently, the test suite is extensible and ready for custom preflight checks to be added.

## Error Handling

- If the Kubernetes connection fails, the application logs an error and exits with code 1
- If the cloud provider used for cluster provisioning cannot be autodetected exit with code 2
- All errors are logged according to the configured log level
- Connection errors include detailed exception information when log level is set to DEBUG
