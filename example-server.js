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
