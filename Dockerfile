FROM trzeci/emscripten-ubuntu AS builder

RUN apt-get update; \
  apt-get install -y \
  build-essential \
  cmake \
  git-core \
  libboost-atomic1.65-dev \
  libboost-chrono1.65-dev \
  libboost-date-time1.65-dev \
  libboost-filesystem1.65-dev \
  libboost-system1.65-dev \
  libboost-thread1.65-dev \
  libglew-dev \
  liblua5.1-0-dev \
  libncurses5-dev \
  libopenal-dev \
  libssl-dev \
  libvorbis-dev \
  mercurial \
  autoconf \
  automake \
  libtool \
  libxmu-dev libxi-dev libgl-dev \
  bison \
  texinfo \
  zlib1g-dev; \
  apt-get clean && apt-get autoclean

WORKDIR /tmp/boost-build
RUN git clone --recursive --jobs=4 https://github.com/boostorg/boost.git
RUN cd boost && ./bootstrap.sh --with-libraries=system,date_time,filesystem,thread,atomic,chrono
RUN cd boost && ./b2 toolset=emscripten install

WORKDIR /tmp
RUN wget https://sourceforge.net/projects/glew/files/glew/2.1.0/glew-2.1.0.tgz/download
RUN tar -xvf download && rm download
RUN cd glew-2.1.0 && emmake make

RUN wget https://www.lua.org/ftp/lua-5.1.5.tar.gz
RUN tar -xvf lua-5.1.5.tar.gz && rm lua-5.1.5.tar.gz
RUN cd lua-5.1.5 && emmake make linux

RUN git clone https://github.com/madler/zlib.git
RUN cd zlib && ./configure && emmake make

# RUN git clone https://github.com/gbeauchesne/gmp.git
# RUN cd gmp && ./.bootstrap && ./configure && emmake make && emmake make check

RUN git clone https://github.com/openssl/openssl.git
RUN cd openssl && ./Configure && emmake make && emmake make install

RUN git clone https://github.com/xiph/vorbis.git
RUN cd vorbis && ./autogen.sh && ./configure && emmake make && emmake make install

RUN git clone https://github.com/kcat/openal-soft.git
RUN cd openal-soft/build && cmake .. && emmake make

RUN cd lua-5.1.5/src && ln -s ../etc/lua.hpp lua.hpp
# RUN cd glew-2.1.0 && ls -la .

WORKDIR /
RUN hg clone -r stable-3.0 http://hg.icculus.org/icculus/physfs/
WORKDIR /physfs/build/
RUN emcmake cmake ..
RUN emmake make -j$(nproc)
RUN emmake make install

COPY ./src/ /otclient/src/.
COPY CMakeLists.txt /otclient/.
WORKDIR /otclient/build/
RUN emcmake cmake \
  -DCMAKE_CXX_LINK_FLAGS=-no-pie -DCMAKE_BUILD_TYPE=Release \
  -DBOOST_ROOT=/tmp/boost-build/boost/  \
  -DCMAKE_FIND_ROOT_PATH=/ \
  -DPHYSFS_LIBRARY=/physfs/build/libphysfs.a -DPHYSFS_INCLUDE_DIR=/physfs/build/libphysfs.a \
  -DLUA_LIBRARY=/tmp/lua-5.1.5/src/liblua.a -DLUA_INCLUDE_DIR=/tmp/lua-5.1.5/src \
  -DZLIB_LIBRARY=/tmp/zlib/libz.so -DZLIB_INCLUDE_DIR=/tmp/zlib \
  # -DGMP_LIBRARY=/tmp/gmp/.libs/libgmp.a -DGMP_INCLUDE_DIR=/tmp/gmp \
  -DOPENSSL_LIBRARIES=/tmp/openssl -DOPENSSL_INCLUDE_DIR=/tmp/openssl/include/openssl -DOPENSSL_LIBRARY=/tmp/openssl/libssl.a -DOPENSSL_CRYPTO_LIBRARY=/tmp/openssl/libcrypto.a \
  -DGLEW_LIBRARY=/tmp/glew-2.1.0/lib/libGLEW.a -DGLEW_INCLUDE_DIR=/tmp/glew-2.1.0/build \
  -DVORBIS_LIBRARY=/tmp/vorbis/lib/.libs/libvorbis.so -DVORBIS_INCLUDE_DIR=/tmp/vorbis \
  -DVORBISFILE_LIBRARY=/tmp/vorbis/lib/.libs/libvorbisfile.so -DVORBISFILE_INCLUDE_DIR=/tmp/vorbis \
  -DOGG_LIBRARY=/tmp/vorbis/lib/.libs/libvorbis.so -DOGG_INCLUDE_DIR=/tmp/vorbis \
  -DOPENAL_LIBRARY=/tmp/openal-soft/build/libopenal.so \
  ..
RUN make -j$(nproc)

FROM ubuntu@sha256:b88f8848e9a1a4e4558ba7cfc4acc5879e1d0e7ac06401409062ad2627e6fb58
RUN apt-get update; \
  apt-get install -y \
  libglew2.0 \
  libopenal1; \
  apt-get clean && apt-get autoclean
COPY --from=builder /otclient/build/otclient /otclient/bin/otclient
COPY ./data/ /otclient/data/.
COPY ./mods/ /otclient/mods/.
COPY ./modules/ /otclient/modules/.
COPY ./init.lua /otclient/.
WORKDIR /otclient
CMD ["./bin/otclient"]
