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

# Set the password for bob to 'bob'
RUN echo "bob:bob" | chpasswd

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



# Install OpenSSH server
RUN apt-get update
RUN apt install -y openssh-server && \
    apt install -y openssh-client && \
    mkdir -p /var/run/sshd


EXPOSE 22
RUN /etc/init.d/ssh start


# Set the user to bob
USER bob

# Create a file in home dir to trigger dotfiles-ng/deploy.sh
RUN touch /home/bob/go.sh

# Write to /home/bob/go.sh to run deploy.sh
RUN echo "#!/bin/bash" > /home/bob/deploy_all.sh && \
    echo "cd ~/dotfiles-ng && ./deploy_all.sh" >> /home/bob/deploy_all.sh && \
    chmod +x /home/bob/deploy_all.sh

# Add a script to quickly apply dotfiles
RUN echo "#!/bin/bash" > /home/bob/apply_dotfiles.sh && \
    echo "sudo -u bob /bin/bash" >> /home/bob/apply_dotfiles.sh && \
    chmod +x /home/bob/apply_dotfiles.sh

RUN echo '#!/bin/bash' > /home/bob/ssh.sh && \
    echo 'sudo /etc/init.d/ssh start' >> /home/bob/ssh.sh && \
    echo 'ssh bob@localhost' >> /home/bob/ssh.sh && \
    chmod +x /home/bob/ssh.sh

RUN echo 'echo "You can ssh to this machine using ./ssh.sh"' >> /home/bob/.bashrc
RUN echo 'echo "Run ./deploy_all.sh to test dotfiles."' >> /home/bob/.bashrc 

RUN echo "#!/bin/bash" > /home/bob/test_bashimu.sh && \
    echo "sudo apt update" >> /home/bob/test_bashimu.sh && \
    echo "sudo apt install -y pipx" >> /home/bob/test_bashimu.sh && \
    echo "$HOME/dotfiles-ng/profiles/desktop/init-scripts/bashimu.sh" >> /home/bob/test_bashimu.sh && \
    echo "$HOME/apply_dotfiles.sh" >> /home/bob/test_bashimu.sh && \
    chmod +x /home/bob/test_bashimu.sh


CMD ["/bin/bash", "-l"]
