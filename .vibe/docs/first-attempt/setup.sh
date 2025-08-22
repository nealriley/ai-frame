#!/bin/bash

# AI Frame Setup Script
# Sets up the WebXR capture system for local development

set -e

echo "========================================="
echo "AI Frame - WebXR Capture System Setup"
echo "========================================="

# Check for required tools
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed"
        return 1
    else
        echo "✅ $1 is installed"
        return 0
    fi
}

echo ""
echo "Checking required tools..."
echo "--------------------------"

MISSING_TOOLS=0

check_command "python3" || MISSING_TOOLS=1
check_command "node" || check_command "nodejs" || MISSING_TOOLS=1
check_command "npm" || MISSING_TOOLS=1
check_command "openssl" || MISSING_TOOLS=1

if [ $MISSING_TOOLS -eq 1 ]; then
    echo ""
    echo "⚠️  Some tools are missing. Please install them first."
    echo ""
fi

# Create directories
echo ""
echo "Creating project structure..."
echo "-----------------------------"

mkdir -p uploads
mkdir -p certs
mkdir -p logs

echo "✅ Directories created"

# Generate self-signed certificate for HTTPS (required for WebXR)
echo ""
echo "Generating HTTPS certificate..."
echo "--------------------------------"

if [ ! -f "certs/cert.pem" ]; then
    openssl req -x509 -newkey rsa:4096 \
        -keyout certs/key.pem \
        -out certs/cert.pem \
        -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=AIFrame/CN=localhost"
    echo "✅ Certificate generated in certs/"
else
    echo "✅ Certificate already exists"
fi

# Install npm packages for serving
echo ""
echo "Installing npm packages..."
echo "--------------------------"

if command -v npm &> /dev/null; then
    npm init -y > /dev/null 2>&1 || true
    npm install --save-dev http-server > /dev/null 2>&1 || true
    echo "✅ npm packages installed"
else
    echo "⚠️  npm not found, skipping package installation"
fi

# Create package.json scripts
echo ""
echo "Setting up npm scripts..."
echo "-------------------------"

if [ -f "package.json" ]; then
    # Update package.json with scripts
    node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('package.json'));
    pkg.scripts = pkg.scripts || {};
    pkg.scripts['serve'] = 'http-server -p 8080';
    pkg.scripts['serve:https'] = 'http-server -S -C certs/cert.pem -K certs/key.pem -p 8443';
    pkg.scripts['serve:python'] = 'python3 -m http.server 8080';
    fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
    echo "✅ npm scripts configured"
fi

# Create example API server
echo ""
echo "Creating example API server..."
echo "-------------------------------"

cat > example-server.js << 'EOF'
const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');

const app = express();
const upload = multer({ dest: 'uploads/' });

// Enable CORS for WebXR access
app.use(cors());
app.use(express.json());

// Upload endpoint
app.post('/upload', upload.any(), (req, res) => {
    console.log('=== Media Upload Received ===');
    console.log('Files:', req.files?.map(f => ({
        fieldname: f.fieldname,
        originalname: f.originalname,
        size: f.size
    })));
    console.log('Text:', req.body.text);
    console.log('Timestamp:', req.body.timestamp);
    
    // Send back AR objects
    res.json({
        success: true,
        message: 'Media received successfully',
        objects: [
            {
                id: Date.now(),
                type: 'text',
                content: `Received ${req.files?.length || 0} files`,
                position: { x: 0, y: 1.5, z: -2 },
                color: '#4ade80'
            }
        ]
    });
});

// Polling endpoint (for future use)
app.get('/poll', (req, res) => {
    res.json({ objects: [] });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`Example API server running on http://localhost:${PORT}`);
    console.log(`Upload endpoint: http://localhost:${PORT}/upload`);
});
EOF

echo "✅ Example API server created (example-server.js)"

# Create run script
echo ""
echo "Creating run script..."
echo "----------------------"

cat > run.sh << 'EOF'
#!/bin/bash

echo "AI Frame - Starting Services"
echo "============================"
echo ""
echo "Choose an option:"
echo "1) Serve with HTTPS (recommended for WebXR)"
echo "2) Serve with HTTP (development only)"
echo "3) Start example API server"
echo "4) Start both HTTPS server and API"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo "Starting HTTPS server on https://localhost:8443"
        npm run serve:https
        ;;
    2)
        echo "Starting HTTP server on http://localhost:8080"
        npm run serve
        ;;
    3)
        echo "Starting example API server..."
        node example-server.js
        ;;
    4)
        echo "Starting both servers..."
        node example-server.js &
        API_PID=$!
        echo "API server PID: $API_PID"
        npm run serve:https
        kill $API_PID 2>/dev/null
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
EOF

chmod +x run.sh
echo "✅ Run script created"

# Create .gitignore
echo ""
echo "Creating .gitignore..."
echo "----------------------"

cat > .gitignore << 'EOF'
node_modules/
uploads/
certs/
logs/
*.log
.DS_Store
.env
EOF

echo "✅ .gitignore created"

# Final instructions
echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "To start the application:"
echo ""
echo "  ./run.sh"
echo ""
echo "Or manually:"
echo ""
echo "  # Serve with HTTPS (required for WebXR):"
echo "  npm run serve:https"
echo ""
echo "  # Start example API server:"
echo "  node example-server.js"
echo ""
echo "Access the app at:"
echo "  https://localhost:8443 (accept self-signed cert)"
echo ""
echo "Configure API endpoint in the app:"
echo "  http://localhost:3001/upload"
echo ""
echo "For Meta Quest:"
echo "  1. Connect Quest to same network"
echo "  2. Find your computer's IP address"
echo "  3. Access https://YOUR-IP:8443 in Quest Browser"
echo ""
echo "========================================="