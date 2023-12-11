job "nginx-proxy" {

  group "nginx" {
    network {
      port "http" {
        static = 80
        to     = 8080
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image          = "nginx:mainline"
        command        = "nginx"
        args           = ["-c", "/local/nginx.conf"]
        ports          = ["http"]
        auth_soft_fail = true
      }

      identity {
        env  = true
        file = true
      }

      resources {
        cpu    = 500
        memory = 256
      }

      template {
        destination = "local/nginx.conf"
        data        = <<EOF
daemon off;

events {}

http {
  server {
    listen 8080;

    location /.well-known/jwks.json {
      proxy_pass http://unix:/secrets/api.sock:$request_uri;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

      # Public endpoint so set auth token
      proxy_set_header Authorization "Bearer {{ env "NOMAD_TOKEN" }}";
    }

    location /.well-known/openid-configuration {
      proxy_pass http://unix:/secrets/api.sock:$request_uri;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

      # Public endpoint so set auth token
      proxy_set_header Authorization "Bearer {{ env "NOMAD_TOKEN" }}";
    }

    location /ui {
      proxy_pass http://unix:/secrets/api.sock:$request_uri;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

      # Public endpoint so set auth token
      proxy_set_header Authorization "Bearer {{ env "NOMAD_TOKEN" }}";
    }

    location / {
      proxy_pass http://unix:/secrets/api.sock:$request_uri;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
  }
}
EOF
      }
    } # task
  }   # group
}     # job
