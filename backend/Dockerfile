FROM tensorflow/tensorflow:2.12.0

WORKDIR /app

# Copy requirements and install - note: TensorFlow is provided by the base image
COPY requirements.txt /app/requirements.txt

RUN python -m pip install --upgrade pip && \
    pip install -r /app/requirements.txt

# Copy the backend source
COPY . /app

EXPOSE 5000

ENV PYTHONUNBUFFERED=1

CMD ["python", "-m", "backend.run"]
