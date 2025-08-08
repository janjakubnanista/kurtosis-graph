fix--style:
    kurtosis lint . --format

lint--style:
    kurtosis lint .
    
# TODO(enable more checks)
lint--code:
    kurtosis-lint \
        --checked-calls \
        --local-imports \
        main.star src/ test/

lint: lint--style lint--code

test:
    kurtosis-test .

clean--test:
    rm -rf .kurtosis-test

clean--examples:
    kurtosis clean

clean: clean--test clean--examples

example name: 
    kurtosis run examples/{{name}}/main.star --enclave {{name}}