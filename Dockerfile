FROM centos:6

ENV PYTHON_VERSION 3.6.5

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

## US English ##
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_COLLATE C
ENV LC_CTYPE en_US.UTF-8

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D

RUN yum -y update

# Install the ca-certificates package
RUN yum -y install ca-certificates

# Enable the dynamic CA configuration feature:
RUN update-ca-trust force-enable

# install python3
RUN set -ex \
        && yum -y install \
        gcc \
        zlib-devel \
        openssl-devel \
        gnupg \
        tar \
        xz \
        make \
        ncurses-dev \
        libressl \
        \
        && curl -so python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
        && curl -so python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
        \
        && export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
        \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
        \
	&& cd /usr/src/python \
	&& ./configure \
                --build="$(arch)" \
                --enable-shared \
                --with-system-expat \
                --with-system-ffi \
                --without-ensurepip \
	&& make -j "$(nproc)" \
	&& make install \
        \
        && echo "/usr/local/lib" >> /etc/ld.so.conf \
        && ldconfig -v \
        \
	&& rm -rf /usr/src/python \
        \
	&& python --version \
	&& python3 --version

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 10.0.1

RUN set -ex \
	&& curl -so get-pip.py 'https://bootstrap.pypa.io/get-pip.py' \
	&& python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	&& pip --version \
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -f get-pip.py

RUN pip install virtualenv

RUN usermod --shell /bin/bash root

RUN yum -y install upstart \
        && yum clean all

CMD ["/bin/bash"]
