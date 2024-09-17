FROM quay.io/jupyter/base-notebook@sha256:876e3c3e40c4f0a25d3a16223a158a2d582b1ad77ac94269d43a5f6256eb4eec

USER root

RUN apt-get -y -qq update && apt-get -y -qq install software-properties-common && add-apt-repository ppa:mozillateam/ppa \
&& echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox \
&& echo Pin: release o=LP-PPA-mozillateam >> /etc/apt/preferences.d/mozilla-firefox \
&& echo Pin-Priority: 1001 >> /etc/apt/preferences.d/mozilla-firefox \
&& apt-get install -y dbus-x11 \
   # xclip is added as jupyter-remote-desktop-proxy's tests requires it
   xclip \
   xfce4 \
   xfce4-panel \
   xfce4-session \
   xfce4-settings \
   xorg \
   xubuntu-icon-theme \
   fonts-dejavu \
   view3dscene \
   python3-pyqt5 \
   xdg-utils \
   gedit \
   gedit-plugins \
   evince \
   gnuplot \
   octave \
   git \
   firefox \
    # Disable the automatic screenlock since the account password is unknown
 && apt-get -y -qq remove xfce4-screensaver \
    # chown $HOME to workaround that the xorg installation creates a
    # /home/jovyan/.cache directory owned by root
    # Create /opt/install to ensure it's writable by pip
 && mkdir -p /opt/install \
 && chown -R $NB_UID:$NB_GID $HOME /opt/install \
 && apt-get -y -qq clean \
 && rm -rf /var/lib/apt/lists/*

# Install a VNC server, either TigerVNC (default) or TurboVNC
ARG vncserver=tigervnc
RUN if [ "${vncserver}" = "tigervnc" ]; then \
        echo "Installing TigerVNC"; \
        apt-get -y -qq update; \
        apt-get -y -qq install \
            tigervnc-standalone-server \
            tigervnc-xorg-extension \
        ; \
        rm -rf /var/lib/apt/lists/*; \
    fi
ENV PATH=/opt/TurboVNC/bin:$PATH
RUN if [ "${vncserver}" = "turbovnc" ]; then \
        echo "Installing TurboVNC"; \
        # Install instructions from https://turbovnc.org/Downloads/YUM
        wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | \
        gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg; \
        wget -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list; \
        apt-get -y -qq update; \
        apt-get -y -qq install \
            turbovnc \
        ; \
        rm -rf /var/lib/apt/lists/*; \
    fi \
  && apt-get -y -qq clean \
  && rm -rf /var/lib/apt/lists/*

ADD . /opt/install
RUN cd /opt/install && \
    fix-permissions /opt/install 

USER $NB_USER

RUN cd /opt/install && \
   mamba env update -n base --file environment.yml && \
   mamba clean -all -y

COPY --chown=$NB_UID:$NB_GID McStasScript/configuration.yaml /tmp

RUN find /opt/conda/lib/ -type d -name mcstasscript -exec cp /tmp/configuration.yaml \{\} \;

RUN . /opt/conda/bin/activate && \
    pip install /opt/install

