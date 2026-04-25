# JupyterLite Server

This repository provides a containerized environment to build and serve a **JupyterLite** instance. JupyterLite is a JupyterLab distribution that runs entirely in the browser, powered by WebAssembly (WASM).

## 🏗️ The Build Philosophy (Multi-Stage)

This project uses a **Two-Stage Docker Build**. This approach keeps the production image extremely small and secure by separating the "factory" from the "product."



1.  **Stage 1: The Builder (Python)**
    * Uses the `requirements.txt` to install the JupyterLite CLI and build tools.
    * Compiles your notebooks in `/content` into static assets (HTML, JS, WASM).
    * **Result:** A `/dist` folder containing the entire website.

2.  **Stage 2: The Runner (Nginx)**
    * The Python environment, compilers, and `requirements.txt` are **discarded**.
    * Only the static `/dist` folder is copied into a lightweight, unprivileged Nginx server.
    * **Result:** A fast, secure production image with zero Python overhead on the server side.

## 📂 Project Structure

* `content/`: Your notebooks (`.ipynb`) and data go here.
* `Dockerfile`: The multi-stage configuration.
* `build.sh`: Automation script for local builds and CI tagging.
* `requirements.txt`: List of packages needed **only during the build phase**.
* `.env`: Version control for Python, Nginx, and JupyterLite.

## 🚀 Usage

### Local Development
To build and start the server locally:
```bash
docker-compose up --build
```
The interface will be available at `http://localhost:8080`.

### CI/CD Deployment
The included GitHub Action (`.github/workflows/docker-image.yml`) automatically builds and pushes the image to **GHCR** (GitHub Container Registry) whenever you push to `main` or `master`.

## 🐍 Important: Python in the Browser
Since the server only delivers static files, the Python code in your notebooks is executed by the **user's browser** via **Pyodide**.

* **Build-time:** The `requirements.txt` is used by the Docker builder to prepare the site.
* **Run-time:** If you need specific libraries (like `numpy` or `pandas`) available in the notebook, you can install them within the notebook using `%pip install <package_name>`.

## 🔒 Security
The final image runs on `nginx-unprivileged`, meaning the process does not have root privileges. This makes it ideal for deployment in strict environments like OpenShift or hardened Kubernetes clusters.
