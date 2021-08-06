FROM alpine AS export

RUN apk add --no-cache squashfs-tools zip

WORKDIR /workspace
RUN wget https://downloads.raspberrypi.org/NOOBS_lite/images/NOOBS_lite-2021-05-28/NOOBS_lite_v3_7.zip && \
	  unzip NOOBS_lite_v3_7.zip && \
	  rm NOOBS_lite_v3_7.zip

WORKDIR /recovery
COPY recovery .

WORKDIR /tmp/squashfs-workspace
RUN unsquashfs -f -d . /workspace/recovery.rfs

# Overwrite init script and add main OS installer script
RUN mv /recovery/* .

# Remove other NOOBS files for smaller FS file
# https://github.com/raspberrypi/noobs/blob/master/noobs/mainwindow.cpp
# Files:
#   * Actual Qt app
#   * Qt app's key mappings
#   * MainWindow::inputSequence's Pixmap
#   * Added system fonts
RUN rm -rf ./usr/bin/recovery ./keymaps ./usr/data ./usr/lib/fonts/*

# Repack
RUN rm /workspace/recovery.rfs && mksquashfs . /workspace/recovery.rfs

WORKDIR /workspace

# Clean up temporary directory
RUN rm -rf /tmp/squashfs-workspace

RUN zip -r recovery.zip .
