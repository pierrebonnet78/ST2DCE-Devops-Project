# Step 1: Use an official Golang image as the base for building
FROM golang:1.21.5 AS builder

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy the Go module files from webapi directory and download dependencies
COPY webapi/go.mod ./
RUN go mod download

# Step 4: Copy the application code from webapi directory
COPY webapi/main.go ./

# Step 5: Build the Go application
RUN CGO_ENABLED=0 go build -o main .

# Step 6: Use a lightweight image to run the application
FROM alpine:latest

# Step 7: Install necessary certificates (required for HTTPS support)
RUN apk --no-cache add ca-certificates

# Step 8: Set the working directory inside the runtime container
WORKDIR /root/

# Step 9: Copy the built application from the builder stage
COPY --from=builder /app/main .

# Step 10: Expose the port your application runs on
EXPOSE 8080

# Step 11: Specify the command to run the application
CMD ["./main"]
