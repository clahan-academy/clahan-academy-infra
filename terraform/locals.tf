locals {
  # Environment determination based on current workspace
  environment = terraform.workspace
  is_prod     = terraform.workspace == "prod"
  is_dev      = terraform.workspace == "dev"

  # Tags configuration
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
    Application = "Clahan-Academy"
  }
  
  primary_tags = merge(local.common_tags, { Region = var.primary_location, Role = "Primary" })
  dr_tags      = merge(local.common_tags, { Region = var.dr_location, Role = "DR" })
  global_tags  = merge(local.common_tags, { Region = "global", Role = "Shared" })
  
  name_prefix = "${var.project_name}-${var.environment}"

  # Map of all 11 container apps (8 custom + 3 open-source)
  container_apps = {
    # Custom services (vignesh8386, all v1.0.0)
    frontend-service = {
      image        = "vignesh8386/clahan-frontend-service:v1.0.0"
      port         = 5173
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 3
      external     = true
      command      = ["/bin/sh", "-c"]
      args         = [
        "sed -i 's/auth-service:4001/auth-service/g; s/admin-service:4002/admin-service/g; s/student-service:4003/student-service/g; s/exam-service:4004/exam-service/g; s/proctoring-service:4005/proctoring-service/g; s/notification-service:4006/notification-service/g; s/listen 5173;/listen 5173; absolute_redirect off;/g' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
      ]
    }
    auth-service = {
      image        = "vignesh8386/clahan-auth-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 3
    }
    admin-service = {
      image        = "vignesh8386/clahan-admin-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 2
    }
    student-service = {
      image        = "vignesh8386/clahan-student-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 3
    }
    exam-service = {
      image        = "vignesh8386/clahan-exam-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 3
      env = {
        AI_SERVICE_URL = "http://ai-service"
      }
    }
    notification-service = {
      image        = "vignesh8386/clahan-notification-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 2
    }
    proctoring-service = {
      image        = "vignesh8386/clahan-proctoring-service:v1.0.0"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 2
      env = {
        AI_SERVICE_URL = "http://ai-service"
      }
    }
    ai-service = {
      image        = "vignesh8386/clahan-ai-service:v1.0.0"
      port         = 8000
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 2
      env = {
        OLLAMA_URL = "http://ollama"
        YOLO_URL   = "http://yolo-v8"
        OCR_URL    = "http://ocr"
      }
    }
    # Open-source services (latest)
    yolo-v8 = {
      image        = "ultralytics/ultralytics:latest"
      port         = 8000
      cpu          = 1.0
      memory       = "2.0Gi"
      max_replicas = 2
    }
    ocr = {
      image        = "python:3.11-slim"
      port         = 8080
      cpu          = 0.5
      memory       = "1.0Gi"
      max_replicas = 2
      command      = ["python", "-c"]
      args         = [
        "import json\nfrom http.server import BaseHTTPRequestHandler, HTTPServer\nclass MockOCRHandler(BaseHTTPRequestHandler):\n    def do_POST(self):\n        if self.path == '/ocr':\n            self.send_response(200)\n            self.send_header('Content-Type', 'application/json')\n            self.end_headers()\n            response = {'text': 'Detected cheating attempt with book/notes. Candidate is holding a mobile device.'}\n            self.wfile.write(json.dumps(response).encode('utf-8'))\n        else:\n            self.send_response(404)\n            self.end_headers()\n    def do_GET(self):\n        if self.path == '/health' or self.path == '/':\n            self.send_response(200)\n            self.send_header('Content-Type', 'application/json')\n            self.end_headers()\n            self.wfile.write(json.dumps({'status': 'healthy'}).encode('utf-8'))\n        else:\n            self.send_response(404)\n            self.end_headers()\nserver = HTTPServer(('0.0.0.0', 8080), MockOCRHandler)\nprint('Mock OCR Server running...')\nserver.serve_forever()"
      ]
    }
    ollama = {
      image        = "ollama/ollama:latest"
      port         = 11434
      cpu          = 1.0
      memory       = "2.0Gi"
      max_replicas = 2
    }
  }
}
