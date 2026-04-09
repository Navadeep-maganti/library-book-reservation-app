#!/usr/bin/env bash
set -o errexit

pip install -r render-requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
