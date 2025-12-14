#!/bin/bash
# AF Prediction API - Deployment Script for VPS
#
# Usage:
#   ./deploy.sh          # Setup and start
#   ./deploy.sh start    # Start only
#   ./deploy.sh stop     # Stop server
#   ./deploy.sh status   # Check status
#   ./deploy.sh logs     # View logs

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
TMUX_SESSION="af_prediction"
PORT="${AF_API_PORT:-5050}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

setup() {
    print_status "Setting up AF Prediction API..."
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    print_status "Python version: $PYTHON_VERSION"
    
    # Create virtual environment
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
    else
        print_status "Virtual environment already exists"
    fi
    
    # Activate venv
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Install dependencies
    print_status "Installing dependencies..."
    pip install -r "$SCRIPT_DIR/requirements.txt"
    
    print_status "Setup complete!"
}

train_model() {
    print_status "Training model (this may take a while)..."
    
    source "$VENV_DIR/bin/activate"
    
    # Download dataset
    print_status "Downloading MIT-BIH AF Database..."
    python "$SCRIPT_DIR/training/download_dataset.py"
    
    # Preprocess
    print_status "Preprocessing data..."
    python "$SCRIPT_DIR/training/preprocess.py"
    
    # Train
    print_status "Training CNN-LSTM model..."
    python "$SCRIPT_DIR/training/train_model.py"
    
    # Evaluate
    print_status "Evaluating model..."
    python "$SCRIPT_DIR/training/evaluate.py"
    
    print_status "Training complete!"
}

start_server() {
    print_status "Starting AF Prediction API server..."
    
    # Check if tmux is installed
    if ! command -v tmux &> /dev/null; then
        print_error "tmux is not installed. Install with: sudo apt install tmux"
        exit 1
    fi
    
    # Check if session already exists
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        print_warning "Server is already running in tmux session '$TMUX_SESSION'"
        print_status "Use './deploy.sh stop' to stop it first"
        return
    fi
    
    # Start new tmux session
    tmux new-session -d -s "$TMUX_SESSION"
    tmux send-keys -t "$TMUX_SESSION" "cd $SCRIPT_DIR && source venv/bin/activate && python app.py" Enter
    
    # Wait a moment and check if it started
    sleep 2
    
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        print_status "Server started in tmux session '$TMUX_SESSION'"
        print_status "API available at: http://localhost:$PORT"
        print_status ""
        print_status "Useful commands:"
        print_status "  View logs:    tmux attach -t $TMUX_SESSION"
        print_status "  Detach:       Press Ctrl+B then D"
        print_status "  Stop server:  ./deploy.sh stop"
    else
        print_error "Failed to start server"
        exit 1
    fi
}

stop_server() {
    print_status "Stopping AF Prediction API server..."
    
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux kill-session -t "$TMUX_SESSION"
        print_status "Server stopped"
    else
        print_warning "Server is not running"
    fi
}

show_status() {
    echo "AF Prediction API Status"
    echo "========================"
    
    # Check tmux session
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo -e "Server: ${GREEN}RUNNING${NC} (tmux session: $TMUX_SESSION)"
    else
        echo -e "Server: ${RED}STOPPED${NC}"
    fi
    
    # Check port
    if command -v lsof &> /dev/null; then
        if lsof -i :$PORT &> /dev/null; then
            echo -e "Port $PORT: ${GREEN}IN USE${NC}"
        else
            echo -e "Port $PORT: ${YELLOW}FREE${NC}"
        fi
    fi
    
    # Check model
    MODEL_PATH="$SCRIPT_DIR/models/trained/af_cnn_lstm.keras"
    if [ -f "$MODEL_PATH" ]; then
        echo -e "Model: ${GREEN}TRAINED${NC} ($MODEL_PATH)"
    else
        echo -e "Model: ${YELLOW}NOT TRAINED${NC}"
        echo "  Run: ./deploy.sh train"
    fi
    
    # Check venv
    if [ -d "$VENV_DIR" ]; then
        echo -e "Venv: ${GREEN}EXISTS${NC}"
    else
        echo -e "Venv: ${RED}NOT FOUND${NC}"
        echo "  Run: ./deploy.sh setup"
    fi
}

show_logs() {
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        print_status "Attaching to tmux session (press Ctrl+B then D to detach)..."
        tmux attach -t "$TMUX_SESSION"
    else
        print_warning "Server is not running"
    fi
}

# Main
case "${1:-}" in
    setup)
        setup
        ;;
    train)
        train_model
        ;;
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 1
        start_server
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    "")
        # Default: full setup and start
        setup
        echo ""
        show_status
        echo ""
        print_status "To train model: ./deploy.sh train"
        print_status "To start API:   ./deploy.sh start"
        ;;
    *)
        echo "Usage: $0 {setup|train|start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  setup    - Create venv and install dependencies"
        echo "  train    - Download dataset and train model"
        echo "  start    - Start API server in tmux"
        echo "  stop     - Stop API server"
        echo "  restart  - Restart API server"
        echo "  status   - Show server status"
        echo "  logs     - Attach to server logs (tmux)"
        exit 1
        ;;
esac
