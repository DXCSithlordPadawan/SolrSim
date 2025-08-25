from flask import Flask, render_template, request, jsonify
import json
from datetime import datetime
import os

app = Flask(__name__)

# Load JSON data files
def load_json_file(filename):
    """Load JSON data from file"""
    try:
        with open(filename, 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        return {"Products": []}
    except json.JSONDecodeError:
        return {"Products": []}

def get_product_by_area(data, area):
    """Get product data by area"""
    for product in data.get("Products", []):
        if product.get("Area") == area:
            return product
    return None

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/threat-check', methods=['POST'])
def threat_check():
    """API endpoint to check for threats"""
    data = request.get_json()
    area = data.get('area', '').upper()
    threat = data.get('threat', '')
    
    if not area or not threat:
        return jsonify({"error": "Area and Threat parameters are required"}), 400
    
    # Valid areas
    valid_areas = ["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"]
    if area not in valid_areas:
        return jsonify({"error": f"Invalid area. Must be one of: {', '.join(valid_areas)}"}), 400
    
    matches = []
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Check product issues data first (critical threats)
    issues_data = load_json_file('productissues.json')
    issues_product = get_product_by_area(issues_data, area)
    
    if issues_product:
        for platform_data in issues_product.get("Platforms", []):
            platform = platform_data.get("platform")
            threats = platform_data.get("Threats", [])
            
            if threat in threats:
                matches.append({
                    "platform": platform,
                    "message": "Threat Active - No Action Possible",
                    "timestamp": timestamp,
                    "threat": threat,
                    "area": area,
                    "type": "critical"
                })
    
    # Check product concessions data (regeneration needed)
    concessions_data = load_json_file('productconcessions.json')
    concessions_product = get_product_by_area(concessions_data, area)
    
    if concessions_product:
        for platform_data in concessions_product.get("Platforms", []):
            platform = platform_data.get("platform")
            threats = platform_data.get("Threats", [])
            
            if threat in threats:
                matches.append({
                    "platform": platform,
                    "message": "Threat Detected - Product Regeneration Required",
                    "timestamp": timestamp,
                    "threat": threat,
                    "area": area,
                    "type": "regeneration"
                })
    
    return jsonify({
        "area": area,
        "threat": threat,
        "matches": matches,
        "total_matches": len(matches)
    })

@app.route('/api/current-products')
def get_current_products():
    """Get current products grouped by area"""
    current_data = load_json_file('currentproduct.json')
    
    grouped_products = {}
    for product in current_data.get("Products", []):
        area = product.get("Area")
        if area not in grouped_products:
            grouped_products[area] = []
        grouped_products[area].append(product)
    
    return jsonify(grouped_products)

@app.route('/api/conceded-products')
def get_conceded_products():
    """Get conceded products without regeneration suggestions"""
    concessions_data = load_json_file('productconcessions.json')
    
    grouped_products = {}
    for product in concessions_data.get("Products", []):
        area = product.get("Area")
        if area not in grouped_products:
            grouped_products[area] = []
        grouped_products[area].append(product)
    
    return jsonify(grouped_products)

@app.route('/api/issue-products')
def get_issue_products():
    """Get products with issues from productissues.json"""
    issues_data = load_json_file('productissues.json')
    
    grouped_products = {}
    for product in issues_data.get("Products", []):
        area = product.get("Area")
        if area not in grouped_products:
            grouped_products[area] = []
        grouped_products[area].append(product)
    
    return jsonify(grouped_products)

@app.route('/api/all-areas')
def get_all_areas():
    """Get list of all valid areas"""
    return jsonify(["OP1", "OP2", "OP3", "OP4", "OP5", "OP6", "OP7", "OP8"])

if __name__ == '__main__':
    # Create templates directory if it doesn't exist
    if not os.path.exists('templates'):
        os.makedirs('templates')
    
    # Create the HTML template
    html_template = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Threat Analysis Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #2c3e50, #34495e);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .subtitle {
            opacity: 0.8;
            font-size: 1.1em;
        }
        
        .tabs {
            display: flex;
            background: #ecf0f1;
            border-bottom: 1px solid #bdc3c7;
        }
        
        .tab {
            flex: 1;
            padding: 15px 20px;
            background: none;
            border: none;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s ease;
        }
        
        .tab:hover {
            background: #d5dbdb;
        }
        
        .tab.active {
            background: #3498db;
            color: white;
        }
        
        .tab-content {
            padding: 30px;
            min-height: 400px;
        }
        
        .tab-pane {
            display: none;
        }
        
        .tab-pane.active {
            display: block;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #2c3e50;
        }
        
        input, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #bdc3c7;
            border-radius: 5px;
            font-size: 16px;
            transition: border-color 0.3s ease;
        }
        
        input:focus, select:focus {
            outline: none;
            border-color: #3498db;
        }
        
        .btn {
            background: linear-gradient(135deg, #3498db, #2980b9);
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
            transition: transform 0.2s ease;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(52, 152, 219, 0.4);
        }
        
        .results {
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 5px;
            border-left: 4px solid #3498db;
        }
        
        .alert {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        
        .alert-danger {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .alert-success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .alert-warning {
            background: #fff3cd;
            color: #856404;
            border: 1px solid #ffeaa7;
        }
        
        .product-group {
            margin-bottom: 25px;
            border: 1px solid #dee2e6;
            border-radius: 5px;
            overflow: hidden;
        }
        
        .product-group-header {
            background: #e9ecef;
            padding: 15px;
            font-weight: 600;
            color: #495057;
        }
        
        .product-item {
            padding: 15px;
            border-bottom: 1px solid #dee2e6;
        }
        
        .product-item:last-child {
            border-bottom: none;
        }
        
        .platform-list {
            margin-top: 10px;
        }
        
        .platform {
            background: #e3f2fd;
            padding: 8px 12px;
            margin: 5px 0;
            border-radius: 3px;
            font-size: 14px;
        }
        
        .threats {
            margin-top: 5px;
            font-size: 12px;
            color: #666;
        }
        
        .loading {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Threat Analysis Dashboard</h1>
            <p class="subtitle">Military Platform Threat Assessment & Product Management</p>
        </header>
        
        <div class="tabs">
            <button class="tab active" onclick="showTab('threat-check')">Threat Analysis</button>
            <button class="tab" onclick="showTab('current-products')">Current Products</button>
            <button class="tab" onclick="showTab('conceded-products')">Conceded Products</button>
            <button class="tab" onclick="showTab('issue-products')">Issue with Products</button>
        </div>
        
        <div class="tab-content">
            <!-- Threat Check Tab -->
            <div id="threat-check" class="tab-pane active">
                <h2>Threat Analysis</h2>
                <p>Enter an area and threat to check for platform vulnerabilities.</p>
                
                <form id="threatForm">
                    <div class="form-group">
                        <label for="area">Operation Area:</label>
                        <select id="area" required>
                            <option value="">Select Area</option>
                            <option value="OP1">OP1</option>
                            <option value="OP2">OP2</option>
                            <option value="OP3">OP3</option>
                            <option value="OP4">OP4</option>
                            <option value="OP5">OP5</option>
                            <option value="OP6">OP6</option>
                            <option value="OP7">OP7</option>
                            <option value="OP8">OP8</option>
                        </select>
                    </div>
                    
                    <div class="form-group">
                        <label for="threat">Threat Identifier:</label>
                        <input type="text" id="threat" placeholder="e.g., S500, SA-24, SU-57" required>
                    </div>
                    
                    <button type="submit" class="btn">Analyze Threat</button>
                </form>
                
                <div id="threatResults"></div>
            </div>
            
            <!-- Current Products Tab -->
            <div id="current-products" class="tab-pane">
                <h2>Current Products</h2>
                <p>View all current products grouped by operational area.</p>
                <div id="currentProductsContent" class="loading">Loading current products...</div>
            </div>
            
            <!-- Conceded Products Tab -->
            <div id="conceded-products" class="tab-pane">
                <h2>Conceded Products</h2>
                <p>View conceded products grouped by operational area.</p>
                <div id="concededProductsContent" class="loading">Loading conceded products...</div>
            </div>
            
            <!-- Issue Products Tab -->
            <div id="issue-products" class="tab-pane">
                <h2>Issue with Products</h2>
                <p>View products with known issues grouped by operational area.</p>
                <div id="issueProductsContent" class="loading">Loading issue products...</div>
            </div>
        </div>
    </div>

    <script>
        // Tab switching functionality
        function showTab(tabId) {
            // Hide all tab panes
            document.querySelectorAll('.tab-pane').forEach(pane => {
                pane.classList.remove('active');
            });
            
            // Remove active class from all tabs
            document.querySelectorAll('.tab').forEach(tab => {
                tab.classList.remove('active');
            });
            
            // Show selected tab pane
            document.getElementById(tabId).classList.add('active');
            
            // Add active class to clicked tab
            event.target.classList.add('active');
            
            // Load data for specific tabs
            if (tabId === 'current-products') {
                loadCurrentProducts();
            } else if (tabId === 'conceded-products') {
                loadConcededProducts();
            } else if (tabId === 'issue-products') {
                loadIssueProducts();
            }
        }

        // Threat analysis form submission
        document.getElementById('threatForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const area = document.getElementById('area').value;
            const threat = document.getElementById('threat').value;
            const resultsDiv = document.getElementById('threatResults');
            
            resultsDiv.innerHTML = '<div class="loading">Analyzing threat...</div>';
            
            try {
                const response = await fetch('/api/threat-check', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ area, threat })
                });
                
                const data = await response.json();
                
                if (response.ok) {
                    displayThreatResults(data);
                } else {
                    resultsDiv.innerHTML = `<div class="alert alert-danger">${data.error}</div>`;
                }
            } catch (error) {
                resultsDiv.innerHTML = `<div class="alert alert-danger">Error: ${error.message}</div>`;
            }
        });

        function displayThreatResults(data) {
            const resultsDiv = document.getElementById('threatResults');
            
            if (data.matches.length === 0) {
                resultsDiv.innerHTML = `
                    <div class="results">
                        <div class="alert alert-success">
                            <strong>No Threats Detected</strong><br>
                            No platforms in ${data.area} are vulnerable to threat "${data.threat}".
                        </div>
                    </div>
                `;
                return;
            }
            
            // Separate critical threats from regeneration needed
            const criticalThreats = data.matches.filter(m => m.type === 'critical');
            const regenerationNeeded = data.matches.filter(m => m.type === 'regeneration');
            
            let html = '<div class="results">';
            
            // Show critical threats first
            if (criticalThreats.length > 0) {
                html += `
                    <div class="alert alert-danger">
                        <strong>CRITICAL: ${criticalThreats.length} Active Threat(s) Detected</strong><br>
                        The following platforms are vulnerable to "${data.threat}" in ${data.area}:
                    </div>
                `;
                
                criticalThreats.forEach(match => {
                    html += `
                        <div class="platform" style="background: #ffebee; color: #c62828; margin: 10px 0;">
                            <strong>Platform:</strong> ${match.platform}<br>
                            <strong>Status:</strong> ${match.message}<br>
                            <strong>Timestamp:</strong> ${match.timestamp}
                        </div>
                    `;
                });
            }
            
            // Show regeneration needed threats
            if (regenerationNeeded.length > 0) {
                html += `
                    <div class="alert alert-warning">
                        <strong>WARNING: ${regenerationNeeded.length} Platform(s) Require Regeneration</strong><br>
                        The following platforms have concessions for "${data.threat}" in ${data.area}:
                    </div>
                `;
                
                regenerationNeeded.forEach(match => {
                    html += `
                        <div class="platform" style="background: #fff8e1; color: #f57c00; margin: 10px 0;">
                            <strong>Platform:</strong> ${match.platform}<br>
                            <strong>Status:</strong> ${match.message}<br>
                            <strong>Action Required:</strong> Product should be regenerated<br>
                            <strong>Timestamp:</strong> ${match.timestamp}
                        </div>
                    `;
                });
            }
            
            html += '</div>';
            resultsDiv.innerHTML = html;
        }

        async function loadCurrentProducts() {
            const contentDiv = document.getElementById('currentProductsContent');
            contentDiv.innerHTML = '<div class="loading">Loading current products...</div>';
            
            try {
                const response = await fetch('/api/current-products');
                const data = await response.json();
                
                displayProducts(data, contentDiv);
            } catch (error) {
                contentDiv.innerHTML = `<div class="alert alert-danger">Error loading current products: ${error.message}</div>`;
            }
        }

        async function loadConcededProducts() {
            const contentDiv = document.getElementById('concededProductsContent');
            contentDiv.innerHTML = '<div class="loading">Loading conceded products...</div>';
            
            try {
                const response = await fetch('/api/conceded-products');
                const data = await response.json();
                
                displayProducts(data, contentDiv);
            } catch (error) {
                contentDiv.innerHTML = `<div class="alert alert-danger">Error loading conceded products: ${error.message}</div>`;
            }
        }

        async function loadIssueProducts() {
            const contentDiv = document.getElementById('issueProductsContent');
            contentDiv.innerHTML = '<div class="loading">Loading issue products...</div>';
            
            try {
                const response = await fetch('/api/issue-products');
                const data = await response.json();
                
                displayProducts(data, contentDiv);
            } catch (error) {
                contentDiv.innerHTML = `<div class="alert alert-danger">Error loading issue products: ${error.message}</div>`;
            }
        }

        function displayProducts(data, container) {
            if (Object.keys(data).length === 0) {
                container.innerHTML = '<div class="alert alert-warning">No products found.</div>';
                return;
            }
            
            let html = '';
            
            Object.keys(data).forEach(area => {
                html += `
                    <div class="product-group">
                        <div class="product-group-header">
                            AREA: ${area} - ${data[area].length} Product(s)
                        </div>
                `;
                
                data[area].forEach(product => {
                    html += `
                        <div class="product-item">
                            <strong>${product.Productname}</strong>
                    `;
                    
                    if (product.Platforms) {
                        html += '<div class="platform-list">';
                        product.Platforms.forEach(platform => {
                            html += `
                                <div class="platform">
                                    PLATFORM: <strong>${platform.platform}</strong>
                                    <div class="threats">Threats: ${platform.Threats.join(', ')}</div>
                                </div>
                            `;
                        });
                        html += '</div>';
                    }
                    
                    html += '</div>';
                });
                
                html += '</div>';
            });
            
            container.innerHTML = html;
        }

        // Load current products on page load
        window.addEventListener('load', function() {
            loadCurrentProducts();
        });
    </script>
</body>
</html>'''
    
    # Write the HTML template to file with UTF-8 encoding
    with open('templates/index.html', 'w', encoding='utf-8') as f:
        f.write(html_template)
    
    print("Starting Threat Analysis Web Application...")
    print("Make sure your JSON files (productissues.json, currentproduct.json, productconcessions.json) are in the same directory as this script")
    print("Access the application at: http://localhost:5000")
    
    app.run(debug=True, host='0.0.0.0', port=5000)