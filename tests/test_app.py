from contextlib import nullcontext
from app.app import handler, getMessage

def test_getMessage():
    assert getMessage('en') == "Hello World"

def test_handler():
    event = {}
    event['queryStringParameters'] = {}
    event['queryStringParameters']['lang'] = 'en'
    output = handler(event, nullcontext)

    assert output["statusCode"] == 200
    assert output['body'] == '{"message": "Hello World"}'

def test_handler_error():
    event = {}
    event['queryStringParameters'] = None
    output = handler(event, nullcontext)

    assert output["statusCode"] == 422