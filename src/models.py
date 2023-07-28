from peewee import (
    AutoField,
    DateTimeField,
    DecimalField,
    ForeignKeyField,
    Model,
    TextField,
    TimestampField,
)


class Institution(Model):
    """
    Table that holds the information of financial institutions. 
    """
    name = TextField()

class Transaction(Model):
    """
    Table that holds transactional data imported from a financial institution.

    Columns:
    id - Local id and primary key of the transaction.
    created_timestamp - Timestamp the row was created in the local db.
    institution - The institution this transaction record came from.
    post_date - The date the transaction was posted.
    description - Description of the transaction as provided by the financial 
                  institution. This is usually the merchant's name.
    amount - The value of the transaction
    """
    id = AutoField()
    created_timestamp = TimestampField()
    institution = ForeignKeyField(Institution)
    post_date = DateTimeField()
    description = TextField()
    amount = DecimalField(max_digits=13, decimal_places=3)

    class Meta:
        indexes = (
            # Unique index on the combined columns of institution, post_date, 
            # description and amount.
            (('institution', 'post_date', 'description', 'amount'), True)
        )