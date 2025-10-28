# ASP.NET Demo for Windows Containers

This is a minimal ASP.NET Web API application for demonstration purposes, designed to run in Windows containers. It exposes a single endpoint:

- `GET /hello` returns a Hello World message.

## Building and Running (Windows Container)

1. Build the Docker image:
   ```powershell
   docker build -t aspnet-demo:windows .
   ```
2. Run the container:
   ```powershell
   docker run -p 8080:80 aspnet-demo:windows
   ```
3. Access the app:
   Open http://localhost:8080/hello in your browser.

## Linux Container Support

Linux container support will be added in the future. The application code is compatible, but the Dockerfile will need to be updated for Linux base images.
