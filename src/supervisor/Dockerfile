# AWS Lambda Python 3.12 base image
FROM public.ecr.aws/lambda/python:3.12

# Copy handler into the Lambda task root (required by the base image)
COPY app.py ${LAMBDA_TASK_ROOT}/

# Tell the Lambda runtime which function to invoke (required - fixes "entrypoint requires the handler name to be the first argument")
CMD ["app.handler"]
