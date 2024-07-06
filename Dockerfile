# Stage 1: Build the application
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build-env
WORKDIR /app

# Install build dependencies and GStreamer
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ make libgstreamer1.0-0 libgstreamer1.0-dev gstreamer1.0-plugins-base \
    libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    gstreamer1.0-doc gstreamer1.0-tools gstreamer1.0-x gstreamer1.0-alsa \
    gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio \
    libc6-dev

# Copy the solution file and project files
COPY VPService.sln ./
COPY VPService/ ./VPService/
COPY Vps2GStreamer/*.csproj ./Vps2GStreamer/
COPY Meta/gstvpsonvifmeta/*.vcxproj ./Meta/gstvpsonvifmeta/
COPY Meta/gstvpsxprotectmeta/*.vcxproj ./Meta/gstvpsxprotectmeta/
COPY VpsUtilities/*.vcxproj ./VpsUtilities/
COPY Plugins/gstvpsboundingboxes/*.vcxproj ./Plugins/gstvpsboundingboxes/
COPY Plugins/gstvpsjpegtranscoder/*.vcxproj ./Plugins/gstvpsjpegtranscoder/
COPY Plugins/gstvpspasstru/*.vcxproj ./Plugins/gstvpspasstru/
COPY Plugins/gstvpsxprotect/*.vcxproj ./Plugins/gstvpsxprotect/

# Copy the entire project and build the C++ projects
COPY . .

WORKDIR /app

# Ensure the /app/bin directory exists
RUN mkdir -p /app/bin

# Build C++ projects
RUN make -C Meta/gstvpsonvifmeta OUTDIR=/app/bin && \
    make -C Meta/gstvpsxprotectmeta OUTDIR=/app/bin && \
    make -C VpsUtilities OUTDIR=/app/bin && \
    make -C Plugins/gstvpsboundingboxes OUTDIR=/app/bin && \
    make -C Plugins/gstvpsjpegtranscoder OUTDIR=/app/bin && \
    make -C Plugins/gstvpspasstru OUTDIR=/app/bin && \
    make -C Plugins/gstvpsxprotect OUTDIR=/app/bin && \
    make -C Plugins/gstvpsopenvinofaces OUTDIR=/app/bin && \
    make -C Plugins/gstvpsmetafromroi OUTDIR=/app/bin && \
    make -C Vps2GStreamer OUTDIR=/app/bin

# Debug step: List files in /app/bin to verify .so files after make
RUN ls -la /app/bin

# Publish the .NET project
WORKDIR /app/VPService
RUN dotnet publish -c Release -o /app/bin

# Debug step: List files in /app/bin to verify .so files after dotnet publish
RUN ls -la /app/bin

# Stage 2: Serve the application
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
WORKDIR /app

# Install GStreamer runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
    gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 \
    gstreamer1.0-qt5 gstreamer1.0-pulseaudio && \
    rm -rf /var/lib/apt/lists/*

# Set LD_LIBRARY_PATH to include the current directory for shared libraries
ENV LD_LIBRARY_PATH=/app/bin

# Copy the published output from the build stage
COPY --from=build-env /app/bin .
ENV GST_DEBUG=2
ENV GST_PLUGIN_PATH=.
ENV LD_PRELOAD="./libgstvpsxprotect.so ./libgstvpsonvifmeta.so ./libgstvpsxprotectmeta.so ./libvpsutilities.so"
# Set the entry point
ENTRYPOINT ["dotnet", "VPService.dll"]
