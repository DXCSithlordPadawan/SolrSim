#!/usr/bin/env python3
"""
Threat Analysis Web Application
Modified to use external JSON configuration for valid areas
"""

import json
import os
from flask import Flask, render_template, request, jsonify, flash, redirect, url_for
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')

# Global variables
threat_data = []
valid_areas = []

def load_config():
    """Load configuration from external JSON file"""
    global valid_areas
    
    config_path = os.environ.get('CONFIG_PATH', './config/areas.json')
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
            valid_areas = config.get('valid_areas', [])
            logger.info(f"Loaded {len(valid_areas)} valid areas from {config_path}")
    except FileNotFoundError:
        logger.error(f"Configuration file not found at {config_path}")
        # Fallback to default areas
        valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
        logger.info("Using default valid areas")
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing configuration file: {e}")
        valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
        logger.info("Using default valid areas")

def save_threat_data():
    """Save threat data to file"""
    data_path = os.environ.get('DATA_PATH', './data/threats.json')
    os.makedirs(os.path.dirname(data_path), exist_ok=True)
    
    try:
        with open(data_path, 'w') as f:
            json.dump(threat_data, f, indent=2)
        logger.info(f"Saved {len(threat_data)} threats to {data_path}")
    except Exception as e:
        logger.error(f"Error saving threat data: {e}")

def load_threat_data():
    """Load threat data from file"""
    global threat_data
    
    data_path = os.environ.get('DATA_PATH', './data/threats.json')
    
    try:
        with open(data_path, 'r') as f:
            threat_data = json.load(f)
        logger.info(f"Loaded {len(threat_data)} threats from {data_path}")
    except FileNotFoundError:
        logger.info("No existing threat data found, starting with empty list")
        threat_data = []
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing threat data file: {e}")
        threat_data = []

@app.route('/')
def index():
    """Main page showing threat analysis form and current threats"""
    return render_template('index.html', 
                         valid_areas=valid_areas, 
                         threats=threat_data)

@app.route('/api/config')
def get_config():
    """API endpoint to get current configuration"""
    return jsonify({
        'valid_areas': valid_areas,
        'total_threats': len(threat_data)
    })

@app.route('/api/threats', methods=['GET'])
def get_threats():
    """API endpoint to get all threats"""
    return jsonify(threat_data)

@app.route('/api/threats', methods=['POST'])
def add_threat():
    """API endpoint to add a new threat"""
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['threat_type', 'area', 'severity', 'description']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Validate area
        if data['area'] not in valid_areas:
            return jsonify({'error': f'Invalid area. Must be one of: {valid_areas}'}), 400
        
        # Validate severity
        valid_severities = ['Low', 'Medium', 'High', 'Critical']
        if data['severity'] not in valid_severities:
            return jsonify({'error': f'Invalid severity. Must be one of: {valid_severities}'}), 400
        
        # Create threat entry
        threat = {
            'id': len(threat_data) + 1,
            'timestamp': datetime.now().isoformat(),
            'threat_type': data['threat_type'],
            'area': data['area'],
            'severity': data['severity'],
            'description': data['description'],
            'reporter': data.get('reporter', 'Anonymous'),
            'status': 'Active'
        }
        
        threat_data.append(threat)
        save_threat_data()
        
        return jsonify({'message': 'Threat added successfully', 'threat': threat}), 201
        
    except Exception as e:
        logger.error(f"Error adding threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/threats/<int:threat_id>', methods=['PUT'])
def update_threat_status(threat_id):
    """API endpoint to update threat status"""
    try:
        data = request.get_json()
        
        # Find threat
        threat = next((t for t in threat_data if t['id'] == threat_id), None)
        if not threat:
            return jsonify({'error': 'Threat not found'}), 404
        
        # Update status
        valid_statuses = ['Active', 'Resolved', 'Investigating']
        if 'status' in data and data['status'] in valid_statuses:
            threat['status'] = data['status']
            threat['updated'] = datetime.now().isoformat()
            save_threat_data()
            return jsonify({'message': 'Threat updated successfully', 'threat': threat})
        else:
            return jsonify({'error': f'Invalid status. Must be one of: {valid_statuses}'}), 400
            
    except Exception as e:
        logger.error(f"Error updating threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/threats/<int:threat_id>', methods=['DELETE'])
def delete_threat(threat_id):
    """API endpoint to delete a threat"""
    try:
        global threat_data
        threat_data = [t for t in threat_data if t['id'] != threat_id]
        save_threat_data()
        return jsonify({'message': 'Threat deleted successfully'})
    except Exception as e:
        logger.error(f"Error deleting threat: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health')
def health_check():
    """Health check endpoint for load balancer"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    # Load configuration and data
    load_config()
    load_threat_data()
    
    # Start the application
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting Threat Analysis App on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)