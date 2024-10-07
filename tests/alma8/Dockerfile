# Use AlmaLinux 8
FROM almalinux:8

# Update repositories and install necessary packages
RUN dnf clean all && \
    dnf -y install epel-release && \
    dnf update -y && \
    dnf -y groupinstall "Development Tools" && \
    dnf -y install python3 python3-devel mariadb-connector-c sshpass && \
    dnf -y install acl sudo && \
    dnf -y install python3-pip git && \
    dnf -y install bzip2 cronie file findutils gzip hostname procps-ng sudo tar tree which unzip xz zip && \
    dnf -y autoremove

# Configure sudoers
RUN sed -i -e 's/^Defaults.*requiretty/Defaults    !requiretty/' \
           -e 's/^%wheel.*ALL$/%wheel    ALL=(ALL)    NOPASSWD: ALL/' /etc/sudoers

# Set up Ansible
RUN mkdir /etc/ansible/
RUN echo -e '[local]\nlocalhost' > /etc/ansible/hosts
RUN pip3 install -U pip
RUN pip3 install 'ansible<2.10' ansible-lint

CMD ["/bin/bash"]
