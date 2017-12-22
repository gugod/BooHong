FROM perl:5.26

COPY . /apps/BooHong
WORKDIR /apps/BooHong
RUN cpanm --notest --installdeps .

EXPOSE 5000
CMD [ "plackup", "app.psgi" ]
