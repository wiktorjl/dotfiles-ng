# This dockerfile helps test dotfiles deployments
FROM debian:latest

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    bash \
    bash-completion \
    git \
    curl \
    vim \
    zsh \
    build-essential \
    sudo \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    procps \
    locales \
    age \
    mc \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/cache/apt/archives/partial


# Add user bob
RUN useradd -m bob

# Set the default shell for bob to bash
RUN chsh -s /bin/bash bob

# Set the locale to en_US.UTF-8
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    echo "LANG=en_US.UTF-8" > /etc/default/locale && \
    echo "LANGUAGE=en_US:en" >> /etc/default/locale && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale && \
    update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Make sure bob can use sudo without a password
RUN echo "bob ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/bob && \
    chmod 0440 /etc/sudoers.d/bob   

# Set the home directory for bob
ENV HOME=/home/bob
ENV USER=bob

# Copy this project to bob's home directory + dotfiles-ng excluding the Dockerfile
COPY --chown=bob:bob . /home/bob/dotfiles-ng

# Make sure all scripts are executable in dotfiles-ng and subdirectories
RUN find /home/bob/dotfiles-ng -type f -name "*.sh" -exec chmod +x {} \; && \
    find /home/bob/dotfiles-ng -type d -exec chmod +x {} \; 

# Set the working directory to bob's home directory
WORKDIR /home/bob/

# Set the user to bob
USER bob

# Create a file in home dir to trigger dotfiles-ng/deploy.sh
RUN touch /home/bob/go.sh

# Write to /home/bob/go.sh to run deploy.sh
RUN echo "#!/bin/bash" > /home/bob/go.sh && \
    echo "cd ~/dotfiles-ng && ./deploy.sh" >> /home/bob/go.sh && \
    chmod +x /home/bob/go.sh

# Add a script to quickly apply dotfiles
RUN echo "#!/bin/bash" > /home/bob/apply_dotfiles.sh && \
    echo "sudo -u bob /bin/bash" >> /home/bob/apply_dotfiles.sh && \
    chmod +x /home/bob/apply_dotfiles.sh

RUN echo 'echo "Run ./go.sh to test dotfiles."' >> /home/bob/.bashrc 

# Run bash in interactive mode
CMD ["/bin/bash", "-i"]

