# Use the official Dart SDK image
FROM dart:stable-sdk

# Set the working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.* ./

# Install dependencies
RUN dart pub get --no-precompile

# Copy the rest of the application code
COPY . .

# Ensure dependencies are properly resolved and build the application
RUN dart pub get --offline && \
  dart compile exe bin/api_dart.dart -o bin/api_dart

# Expose the port the app runs on
EXPOSE 8080

# Set the default command
CMD ["./bin/api_dart"]
