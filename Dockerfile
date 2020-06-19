FROM jupyter/minimal-notebook:latest

ARG NB_USER=jupyteruser
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

WORKDIR ${HOME}

USER root

# .NET SDK install uses curl
RUN apt-get update \
    && apt-get install -y curl

# THE NEXT ENV AND 2 RUN's ARE FROM https://github.com/dotnet/dotnet-docker/blob/dad8a11d3193b10736d1b591aa4fae0dbda42566/src/sdk/3.1/focal/amd64/Dockerfile
ENV \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # PowerShell telemetry for docker image usage
    POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-DotnetCoreSDK-Ubuntu-20.04

# Install .NET CLI dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu66 \
        libssl1.1 \
        libstdc++6 \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Install .NET Core SDK
RUN dotnet_sdk_version=3.1.301 \
    && curl -SL --output dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Sdk/$dotnet_sdk_version/dotnet-sdk-$dotnet_sdk_version-linux-x64.tar.gz \
    && dotnet_sha512='dd39931df438b8c1561f9a3bdb50f72372e29e5706d3fb4c490692f04a3d55f5acc0b46b8049bc7ea34dedba63c71b4c64c57032740cbea81eef1dce41929b4e' \
    && echo "$dotnet_sha512 dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -ozxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet \
    # Trigger first run experience by running arbitrary cmd
    && dotnet help
    
# Install PowerShell global tool
RUN dotnet tool install -g powershell

# Copy package sources

COPY ./nuget.config ${HOME}/nuget.config

RUN chown -R ${NB_UID} ${HOME}
USER ${USER}

#Install nteract 
RUN pip install nteract_on_jupyter

# Install lastest build from master branch of Microsoft.DotNet.Interactive from myget
RUN dotnet tool install -g Microsoft.dotnet-interactive --add-source "https://dotnet.myget.org/F/dotnet-try/api/v3/index.json"

#latest stable from nuget.org
#RUN dotnet tool install -g Microsoft.dotnet-interactive --add-source "https://api.nuget.org/v3/index.json"

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet interactive jupyter install

# Enable telemetry once we install jupyter for the image
ENV DOTNET_TRY_CLI_TELEMETRY_OPTOUT=false

# NOTE: EVERYTHING ABOVE THIS SHOULD BE PROVIDED BY A dotnet-interactive OFFICIAL IMAGE
# THIS MEANS IN THE FUTURE, THE ABOVE WILL TURN INTO SIMPLY:
# FROM dotnet/interactive:latest

USER root

# INSTALL ANYTHING ELSE YOU WANT IN THIS CONTAINER HERE

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin

# Set up kubectl autocompletion
RUN apt-get update && apt-get install -y bash-completion \
    && kubectl completion bash >/etc/bash_completion.d/kubectl

USER ${USER}

# Copy notebooks (So MyBinder will work)
COPY . ${HOME}/data/JupyterNotebooks/

# Modify the permissions
USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${USER}

# Setup volume (So you can run locally with mounted filesystem)
VOLUME ${HOME}/data/JupyterNotebooks/

# Set root to notebooks
WORKDIR ${HOME}/data/JupyterNotebooks/
