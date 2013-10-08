There are three test data directories:

- 'data': These files test *specific* conversions and are expected to have
  specific data in them during testing. Do not put test data here unless
  you are sure it meets all requirements needed to pass.

- 'data-bad': These files are bad META files that fail validation, but can
  be fixed via the Converter.

- 'data-fail': These files are bad META files that fail validation and
  can't be fixed.
