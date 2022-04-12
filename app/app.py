import os
import json
import time
import boto3

TABLE_NAME = os.environ["TableName"]

class Error(Exception):
    """Base class for other exceptions"""

    pass


class NoRecordError(Error):
    """Raised when no record found"""

    pass


class ResultEntity:
    def __init__(self, lang, message):
        """
        This function used to initiate values to the class variables
        """
        self.Lang = lang
        self.Message = message


class DbEntity:
    def __init__(self, lang):
        """
        This function used to initiate values to the class variables
        """
        self.Lang = lang


def lambda_handler(event, context):
    try:
        if event["queryStringParameters"] == None:
            lang = "en"
        else:
            lang = event["queryStringParameters"]["lang"]

        record = get_message(DbEntity(lang))
        result = ResultEntity(**record)

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
            },
            "body": json.dumps(result, default=lambda o: o.__dict__),
        }
    except Exception as e:
        return {"statusCode": 500, "error": str(e)}


def get_message(item):
    """
    This function will check the entry in dynamodb if exists will return item
    :param lang
    :return: message or return NoRecordError Exception
    """

    dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
    table = dynamodb.Table(TABLE_NAME)

    response = table.get_item(
        Key={"lang": item.Lang},
    )

    time.sleep(1)

    if "Item" not in response:
        raise NoRecordError("No Records Found.")
    else:
        return response["Item"]
