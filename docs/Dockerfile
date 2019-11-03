FROM corpusops/python:3
RUN apt-get update -qq
ADD docs/apt.txt ./
RUN apt-get install -qq $(cat apt.txt)
ADD docs/req*.txt ./
RUN pip install -r requirements.txt
ADD docs /code/docs
ADD local /code/local/
WORKDIR /code/docs
ENTRYPOINT ["/code/docs/entry.sh"]
