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
  libegl1-mesa-dev \
  zlib1g-dev; \
  apt-get clean && apt-get autoclean

WORKDIR /tmp/boost-build
RUN git clone --recursive --jobs=4 https://github.com/boostorg/boost.git
RUN cd boost && ./bootstrap.sh --with-libraries=system,date_time,filesystem,thread,atomic,chrono
RUN cd boost && ./b2 toolset=emscripten install

WORKDIR /tmp
RUN wget https://sourceforge.net/projects/glew/files/glew/2.1.0/glew-2.1.0.tgz/download
RUN tar -xvf download && rm download
RUN cd glew-2.1.0/build && emcmake cmake ./cmake && emmake make -j4 glew_s
# RUN cd glew-2.1.0 && emmake make -j4

RUN wget https://www.lua.org/ftp/lua-5.1.5.tar.gz
RUN tar -xvf lua-5.1.5.tar.gz && rm lua-5.1.5.tar.gz
RUN cd lua-5.1.5 && emmake make linux

# RUN git clone https://github.com/gbeauchesne/gmp.git
# RUN cd gmp && ./.bootstrap && ./configure && emmake make && emmake make check

RUN git clone https://github.com/openssl/openssl.git
RUN cd openssl && ./Configure && emmake make && emmake make install

RUN git clone https://github.com/xiph/ogg.git
RUN mkdir ogg/build
RUN cd ogg/build && emcmake cmake .. && emmake make
RUN cp ogg/include/ogg/ogg.h ogg/build/include/ogg/ogg.h 
RUN cp ogg/include/ogg/os_types.h ogg/build/include/ogg/os_types.h 
# RUN ls -la ogg/include/ogg ogg/build/include/ogg

RUN git clone https://github.com/xiph/vorbis.git
# RUN cd vorbis && ./autogen.sh && ./configure
RUN cd vorbis && mkdir build && cd build && emcmake cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release .. -DOGG_LIBRARY=/tmp/ogg/build/libogg.a -DOGG_INCLUDE_DIR=/tmp/ogg/build/include && emcmake cmake --build .
RUN cd vorbis/build && make
# RUN cd vorbis && emcmake cmake -DOGG_LIBRARY=/tmp/ogg/build/libogg.a -DOGG_INCLUDE_DIR=/tmp/ogg/build/include . && emmake make
RUN cp -r ogg/build/include/ogg vorbis/include/

RUN git clone https://github.com/kcat/openal-soft.git
RUN cd openal-soft/build && cmake .. && emmake make

RUN git clone https://github.com/madler/zlib.git
RUN cd zlib && mkdir build && cd build && emcmake cmake .. && emmake make && emmake make install

RUN cd lua-5.1.5/src && ln -s ../etc/lua.hpp lua.hpp

RUN hg clone -r stable-3.0 http://hg.icculus.org/icculus/physfs/
RUN mkdir -p physfs/build/
RUN cd physfs/build && emcmake cmake .. && emmake make -j$(nproc) && emmake make install

RUN git clone https://github.com/mesa3d/mesa.git
RUN pip3 install setuptools
RUN pip3 install meson
RUN mkdir -p mesa/build && cd mesa/build && meson .. && ninja install

### DEBUGS
RUN ls -lah /tmp/mesa/
# RUN ls -lah /usr/lib/x86_64-linux-gnu/ | grep -i gles
# RUN cd /tmp/vorbis && ls -lah . build build/lib

WORKDIR /
COPY ./src/ /otclient/src/.
COPY CMakeLists.txt /otclient/.
WORKDIR /otclient/build/
RUN emcmake cmake \
  -DCMAKE_CXX_LINK_FLAGS=-no-pie -DCMAKE_BUILD_TYPE=Release \
  # -DBOOST_ROOT=/tmp/boost-build/boost/  \
  -DCMAKE_FIND_ROOT_PATH=/ \
  -DPHYSFS_LIBRARY=/tmp/physfs/build/libphysfs.a -DPHYSFS_INCLUDE_DIR=/tmp/physfs/build/libphysfs.a \
  -DLUA_LIBRARY=/tmp/lua-5.1.5/src/liblua.a -DLUA_INCLUDE_DIR=/tmp/lua-5.1.5/src \
  -DZLIB_LIBRARY=/tmp/zlib/build/libz.a -DZLIB_INCLUDE_DIR=/tmp/zlib \
  # -DGMP_LIBRARY=/tmp/gmp/.libs/libgmp.a -DGMP_INCLUDE_DIR=/tmp/gmp \
  -DOPENSSL_LIBRARIES=/tmp/openssl -DOPENSSL_INCLUDE_DIR=/tmp/openssl/include/openssl -DOPENSSL_LIBRARY=/tmp/openssl/libssl.a -DOPENSSL_CRYPTO_LIBRARY=/tmp/openssl/libcrypto.a \
  # -DGLEW_LIBRARY=/tmp/glew-2.1.0/build/lib/libGLEW.a -DGLEW_INCLUDE_DIR=/tmp/glew-2.1.0/include \
  -DVORBIS_LIBRARY=/tmp/vorbis/build/lib/libvorbis.a -DVORBIS_INCLUDE_DIR=/tmp/vorbis/include \
  -DVORBISFILE_LIBRARY=/tmp/vorbis/build/lib/libvorbisfile.a -DVORBISFILE_INCLUDE_DIR=/tmp/vorbis/include \
  -DOGG_LIBRARY=/tmp/ogg/build/libogg.a -DOGG_INCLUDE_DIR=/tmp/ogg/build/include \
  -DOPENAL_LIBRARY=/tmp/openal-soft/build/libopenal.so \
  -DEGL_LIBRARY=/usr/lib/x86_64-linux-gnu/libEGL_mesa.so.0 \
  -DOPENGLES1_LIBRARY=/usr/lib/x86_64-linux-gnu/libGLESv2_CM.so \
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
