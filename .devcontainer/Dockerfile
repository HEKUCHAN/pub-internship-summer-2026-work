FROM mcr.microsoft.com/devcontainers/python:3.11

RUN apt-get update

# install uv
USER vscode
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# bashrc
COPY devcontainer.bashrc /home/vscode/.bashrc
