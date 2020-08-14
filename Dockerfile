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
  bison \
  texinfo \
  zlib1g-dev; \
  apt-get clean && apt-get autoclean

WORKDIR /tmp/boost-build
RUN git clone --recursive --jobs=4 https://github.com/boostorg/boost.git
RUN cd boost && ./bootstrap.sh --with-libraries=system,date_time,filesystem,thread,atomic,chrono
RUN cd boost && ./b2 toolset=emscripten
# RUN cd boost && ./b2 toolset=emscripten link=static threading=multi cflags="-s USE_PTHREADS=1" cxxflags="-s USE_PTHREADS=1"

WORKDIR /tmp
RUN git clone https://github.com/lua/lua.git
RUN cd lua && emmake make
RUN git clone https://github.com/madler/zlib.git
RUN cd zlib && ./configure && emmake make
RUN git clone https://github.com/gbeauchesne/gmp.git
RUN cd gmp && ./.bootstrap && ./configure && emmake make && emmake make check
RUN git clone https://github.com/nigels-com/glew.git
RUN cd glew && cd auto && emmake make && cd .. && emmake make && emmake make install
RUN git clone https://github.com/openssl/openssl.git
RUN cd openssl && ./Configure && emmake make && emmake make install
RUN git clone https://github.com/xiph/vorbis.git
RUN cd vorbis && ./autogen.sh && ./configure && emmake make && emmake make install 


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
  # -DBOOST_INCLUDEDIR=/tmp/boost-build/boost/stage/lib -DBOOST_LIBRARYDIR=/tmp/boost-build/boost/stage/lib \
  -DCMAKE_FIND_ROOT_PATH=/ \
  -DPHYSFS_LIBRARY=/physfs/build -DPHYSFS_INCLUDE_DIR=/physfs/build \
  -DLUA_LIBRARY=/tmp/lua -DLUA_INCLUDE_DIR=/tmp/lua \
  -DZLIB_LIBRARY=/tmp/zlib -DZLIB_INCLUDE_DIR=/tmp/zlib \
  -DGMP_LIBRARY=/tmp/gmp -DGMP_INCLUDE_DIR=/tmp/gmp \
  -DOPENSSL_LIBRARIES=/usr/local/lib/openssl -DOPENSSL_INCLUDE_DIR=/tmp/openssl \
  -DGLEW_LIBRARY=/tmp/glew -DGLEW_INCLUDE_DIR=/tmp/glew \
  -DVORBIS_LIBRARY=/tmp/vorbis -DVORBIS_INCLUDE_DIR=/tmp/vorbis \
  -DVORBISFILE_LIBRARY=/tmp/vorbis -DVORBISFILE_INCLUDE_DIR=/tmp/vorbis \
  -DOPENAL_LIBRARY=/tmp/vorbis -DOGG_LIBRARY=/tmp/vorbis \
  ..
RUN emmake make -j$(nproc)

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
