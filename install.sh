#!/bin/bash

# HomeHub Installation Script for macOS
# This script sets up HomeHub with Docker for Tom and Eleanor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HomeHub Installation Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
print_status "Checking operating system..."
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only. Detected: $OSTYPE"
    exit 1
fi
print_success "Running on macOS"

# Check for Docker
print_status "Checking for Docker installation..."
DOCKER_CMD=""
if command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
elif [ -f "/usr/local/bin/docker" ]; then
    DOCKER_CMD="/usr/local/bin/docker"
elif [ -f "/Applications/Docker.app/Contents/Resources/bin/docker" ]; then
    DOCKER_CMD="/Applications/Docker.app/Contents/Resources/bin/docker"
    # Add Docker to PATH for this session
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
fi

# Set DOCKER_HOST for macOS Docker Desktop
if [ -S "$HOME/.docker/run/docker.sock" ]; then
    export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
fi

if [ -z "$DOCKER_CMD" ]; then
    print_error "Docker is not installed. Please install Docker Desktop from https://www.docker.com/products/docker-desktop"
    exit 1
fi
print_success "Docker is installed ($($DOCKER_CMD --version))"

# Check for Docker Compose
print_status "Checking for Docker Compose..."
if ! $DOCKER_CMD compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please ensure Docker Desktop includes Compose V2."
    exit 1
fi
print_success "Docker Compose is installed ($($DOCKER_CMD compose version))"

# Check for Node.js and npm (for CSS build)
print_status "Checking for Node.js and npm..."
if ! command -v node &> /dev/null; then
    print_warning "Node.js is not installed. CSS building will be skipped."
    print_warning "Install Node.js from https://nodejs.org/ if you need to rebuild CSS."
    NODE_AVAILABLE=false
else
    print_success "Node.js is installed ($(node --version))"
    if ! command -v npm &> /dev/null; then
        print_warning "npm is not installed. CSS building will be skipped."
        NODE_AVAILABLE=false
    else
        print_success "npm is installed ($(npm --version))"
        NODE_AVAILABLE=true
    fi
fi

# Check for Python (optional, for local development)
print_status "Checking for Python..."
if ! command -v python3 &> /dev/null; then
    print_warning "Python 3 is not installed. Only Docker-based deployment will be available."
else
    print_success "Python 3 is installed ($(python3 --version))"
fi

# Check if port 5002 is available
print_status "Checking if port 5002 is available..."
if lsof -Pi :5002 -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_error "Port 5002 is already in use. Please stop the service using this port or modify the port in compose.yml"
    print_status "You can find what's using port 5002 with: lsof -i :5002"
    exit 1
fi
print_success "Port 5002 is available"

echo ""
print_status "All prerequisites checked successfully!"
echo ""

# Create config.yml from config-example.yml if it doesn't exist
print_status "Setting up configuration file..."
if [ -f "config.yml" ]; then
    print_warning "config.yml already exists. Creating backup as config.yml.backup"
    cp config.yml config.yml.backup
fi

cat > config.yml << 'EOF'
instance_name: "Tom and Eleanor's Hub"
password: "3056"
admin_name: "Administrator"
feature_toggles:
  shopping_list: true
  media_downloader: true
  pdf_compressor: true
  qr_generator: true
  notes: true
  shared_cloud: true
  who_is_home: true
  chores: true
  recipes: true
  expiry_tracker: true
  url_shortener: true
  expense_tracker: true
family_members:
  - Tom
  - Eleanor
reminders:
  time_format: "12h"
  categories:
    - key: health
      label: Health
      color: "#dc2626"
    - key: bills
      label: Bills
      color: "#0d9488"
    - key: school
      label: School
      color: "#7c3aed"
    - key: family
      label: Family
      color: "#2563eb"
theme:
  primary_color: "#1d4ed8"
  secondary_color: "#a0aec0"
  background_color: "#f7fafc"
  card_background_color: "#fff"
  text_color: "#333"
  sidebar_background_color: "#2563eb"
  sidebar_text_color: "#ffffff"
  sidebar_link_color: "rgba(255,255,255,0.95)"
  sidebar_link_border_color: "rgba(255,255,255,0.18)"
  sidebar_active_color: "#3b82f6"
EOF

print_success "config.yml created with Tom and Eleanor as family members"

# Create .env file with SECRET_KEY
print_status "Generating SECRET_KEY for .env file..."
SECRET_KEY=$(openssl rand -hex 32)
cat > .env << EOF
SECRET_KEY=${SECRET_KEY}
EOF
print_success ".env file created with generated SECRET_KEY"

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p uploads media pdfs data
print_success "Directories created: uploads, media, pdfs, data"

# Install npm dependencies and build CSS if Node is available
if [ "$NODE_AVAILABLE" = true ]; then
    print_status "Installing npm dependencies..."
    npm install
    print_success "npm dependencies installed"

    print_status "Building CSS with Tailwind..."
    npm run build:css
    print_success "CSS built successfully"
else
    print_warning "Skipping CSS build (Node.js/npm not available). Using pre-built CSS from Docker image."
fi

# Verify compose.yml exists
if [ ! -f "compose.yml" ]; then
    print_error "compose.yml not found in current directory"
    exit 1
fi

# Pull the latest Docker image
print_status "Pulling latest HomeHub Docker image..."
$DOCKER_CMD compose pull
print_success "Docker image pulled successfully"

# Start the container
print_status "Starting HomeHub container..."
$DOCKER_CMD compose up -d
print_success "HomeHub container started successfully"

# Wait a moment for the container to fully start
sleep 3

# Check if container is running
if $DOCKER_CMD compose ps | grep -q "Up"; then
    print_success "HomeHub is running!"
else
    print_error "Container failed to start. Check logs with: docker compose logs"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "HomeHub is now running at: ${BLUE}http://localhost:5002${NC}"
echo -e "Instance Name: ${BLUE}Tom and Eleanor's Hub${NC}"
echo -e "Family Members: ${BLUE}Tom, Eleanor${NC}"
echo -e "Password: ${BLUE}3056${NC}"
echo ""
echo "Useful commands:"
echo "  - View logs:        docker compose logs -f"
echo "  - Stop HomeHub:     docker compose stop"
echo "  - Start HomeHub:    docker compose start"
echo "  - Restart HomeHub:  docker compose restart"
echo "  - Remove HomeHub:   docker compose down"
echo ""
print_success "Enjoy your HomeHub!"
