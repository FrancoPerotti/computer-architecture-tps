"""Shared preference values and validation, independent of storage and HTTP."""

DEFAULT_PREFERENCES = {
    "schema_version": 1,
    "default_author": None,
    "record_by_default": True,
    "last_serial_port": None,
    "ui_zoom": 1.0,
    "language": "es",
}


def validate_preferences(value):
    return (
        isinstance(value, dict)
        and set(value) == set(DEFAULT_PREFERENCES)
        and type(value["schema_version"]) is int
        and value["schema_version"] == 1
        and (
            value["default_author"] is None
            or isinstance(value["default_author"], str)
            and bool(value["default_author"].strip())
        )
        and type(value["record_by_default"]) is bool
        and (
            value["last_serial_port"] is None
            or isinstance(value["last_serial_port"], str)
            and bool(value["last_serial_port"])
        )
        and type(value["ui_zoom"]) in (int, float)
        and 0.5 <= value["ui_zoom"] <= 2.0
        and value["language"] == "es"
    )
