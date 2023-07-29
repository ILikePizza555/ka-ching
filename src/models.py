from peewee import (
    DateTimeField,
    DecimalField,
    ForeignKeyField,
    Model,
    TextField,
    TimestampField,
)
from playhouse.apsw_ext import APSWDatabase
from playhouse.sqlite_ext import JSONField

"""
Db variable passed to all the models. 
The connection is "None" because it's loaded at runtime.

See: https://docs.peewee-orm.com/en/latest/peewee/database.html#setting-the-database-at-run-time"""
db = APSWDatabase(None)

class BaseModel(Model):
    """Base model for all the other models."""
    class Meta():
        database = db

class Institution(BaseModel):
    """
    Table that holds the information of financial institutions. 
    """
    name = TextField()

class Transaction(Model):
    """
    Table that holds transactional data imported from a financial institution.

    Columns:
    created_timestamp - Timestamp the row was created in the local db.
    institution - The institution this transaction record came from.
    post_date - The date the transaction was posted.
    description - Description of the transaction as provided by the financial 
                  institution. This is usually the merchant's name.
    amount - The value of the transaction
    """
    created_timestamp = TimestampField()
    institution = ForeignKeyField(Institution)
    post_date = DateTimeField()
    description = TextField()
    amount = DecimalField(max_digits=13, decimal_places=3)

    class Meta:
        database = db
        indexes = (
            # Unique index on the combined columns of institution, post_date, 
            # description and amount.
            (("institution", "post_date", "description", "amount"), True)
        )

class TransactionExt(BaseModel):
    """Table that holds extension data as JSON documents."""
    transaction = ForeignKeyField(Transaction, backref="exts", lazy_load=True)
    document = JSONField()

class Tag(BaseModel):
    name = TextField(unique=True)

class TransactionTagRelation(BaseModel):
    """Relates the many-to-many relationship between tags and transactions"""
    transaction = ForeignKeyField(Transaction)
    tag = ForeignKeyField(Tag)