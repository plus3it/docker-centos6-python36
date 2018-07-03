FROM centos:6

ENV PYTHON_MINOR_VERSION 3.6
ENV PYTHON_PATCH_VERSION 6
ENV PYTHON_VERSION ${PYTHON_MINOR_VERSION}.${PYTHON_PATCH_VERSION}

ENV INSTALL_BASE /opt/python
ENV INSTALL_LOC $INSTALL_BASE/$PYTHON_VERSION

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 10.0.1

# ensure local python is preferred over distribution python
ENV PATH $INSTALL_LOC/bin:$PATH

## US English ##
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_COLLATE C
ENV LC_CTYPE en_US.UTF-8

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D

# Start by making sure your system is up-to-date:
RUN yum update -y

# Compilers and related tools:
RUN yum groupinstall -y "development tools"

# Libraries needed during compilation to enable all features of Python:
RUN yum install -y \
        zlib-devel \
        bzip2-devel \
        openssl-devel \
        ncurses-devel \
        sqlite-devel \
        readline-devel \
        tk-devel \
        gdbm-devel \
        db4-devel \
        libpcap-devel \
        xz-devel \
        expat-devel \
        gnupg

# If you are on a clean "minimal" install of CentOS you also need the wget tool:
RUN yum install -y wget

# Install the ca-certificates package
RUN yum install -y ca-certificates

# Enable the dynamic CA configuration feature:
RUN update-ca-trust force-enable

# adjust linking
RUN cd /usr/lib64 \
        #&& ln -s libssl.so.10 libssl.so.1.0.0 \
        #&& ln -s libcrypto.so.10 libcrypto.so.1.0.0 \
        && cp libcrypto.so.10 libcrypto.so.1.0.0 \
        && cp libssl.so.10 libssl.so.1.0.0 \
        && ls -hal

ENV LD_LIBRARY_PATH $INSTALL_LOC/lib:/usr/lib64:/lib64

# install python3
RUN set -ex \
        && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
        && wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
        && export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
        #&& export LD_LIBRARY_PATH=$INSTALL_LOC/lib \
        #&& ./configure \
        #        --build="$(arch)" \
        #        --prefix=/usr/local \
        #        --enable-shared \
        #        LDFLAGS="-Wl,-rpath $INSTALL_LOC/lib" \
        && ./configure \
                --prefix=$INSTALL_LOC \
                --with-wide-unicode \
                --enable-shared \
                --enable-ipv6 \
                --enable-loadable-sqlite-extensions \
                --with-computed-gotos \
                --libdir=$INSTALL_LOC/lib \
                CFLAGS="-g -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security" \
                LDFLAGS="-L$INSTALL_LOC/lib -Wl,-rpath=$INSTALL_LOC/lib " \
                CPPFLAGS="-I$INSTALL_LOC/include " \
        && make -j "$(nproc)" \
        && make altinstall \
        #&& echo "$INSTALL_LOC/lib" >> /etc/ld.so.conf \
        #&& ldconfig -v \
	&& rm -rf /usr/src/python

# strip symbols from the shared library to reduce the memory footprint.
#RUN strip $INSTALL_LOC/lib/libpython${PYTHON_MINOR_VERSION}m.so.1.0

# make some useful symlinks that are expected to exist
RUN cd $INSTALL_LOC/bin \
	&& ln -s idle${PYTHON_MINOR_VERSION} idle \
	&& ln -s pydoc${PYTHON_MINOR_VERSION} pydoc \
	&& ln -s python${PYTHON_MINOR_VERSION} python3 \
	&& ln -s python${PYTHON_MINOR_VERSION}m-config python-config

RUN set -ex \
	&& wget https://bootstrap.pypa.io/get-pip.py \
	&& python3 get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	&& pip --version \
	&& find $INSTALL_BASE -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -f get-pip.py

RUN pip install \
        virtualenv \
        attrs \
        funcsigs \
        mock \
        nose \
        numpy \
        pbr \
        pluggy \
        py \
        pytest \
        setuptools \
        six \
        wheel

RUN yum install -y upstart \
        && yum clean all

CMD ["/bin/bash"]
