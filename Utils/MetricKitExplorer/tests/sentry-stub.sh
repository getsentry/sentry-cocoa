#!/bin/bash
# AI-generated development aid for MetricKit Explorer, not a human-reviewed,
# verified source of correctness. Take its assumptions and coverage with a grain
# of salt, and independently validate important behavior.
set -euo pipefail
printf '%s\n' "$*" >>"$FIXTURE_DIR/calls"
case "$1" in
--version) printf '%s\n' "${STUB_VERSION:-0.45.0}" ;;
cli) printf '%s\n' '{"defaults":{"organization":"fixture-org","project":"fixture-project"}}' ;;
api)
    case "$2" in
    *'?query='*)
        if [[ "${STUB_MODE:-}" = forbidden-first && "$2" = *'query=11111111-1111-1111-1111-111111111111&'* ]]; then
            jq -n --arg arch "$FIXTURE_ARCH" '{status:200,body:[{id:"44",debugId:"11111111-1111-1111-1111-111111111111",cpuName:$arch,symbolType:"macho",data:{features:["debug"]}}]}'
        elif [[ "${STUB_MODE:-}" = lookup-forbidden ]]; then
            printf '%s\n' '{"status":403,"body":"private error content"}'
            exit 60
        elif [[ "${STUB_MODE:-}" = missing || "$2" != *"query=$FIXTURE_UUID&"* ]]; then
            printf '%s\n' '{"status":200,"body":[]}'
        elif [[ "${STUB_MODE:-}" = lookup-failure ]]; then
            printf '%s\n' '{"status":401,"body":"private error content"}'
            exit 60
        else
            jq -n --arg uuid "$FIXTURE_UUID" --arg arch "$FIXTURE_ARCH" '{status:200,body:[
                        {id:"41",debugId:$uuid,cpuName:"wrong-arch",symbolType:"macho",data:{features:["debug"]}},
                        {id:"43",debugId:$uuid,cpuName:$arch,symbolType:"macho",data:{features:["symtab"]}},
                        {id:"42",debugId:$uuid,cpuName:$arch,symbolType:"macho",data:{features:["debug","symtab"]}}
                    ]}'
        fi
        ;;
    *'?id=44')
        printf '%s\n' '{"status":403,"body":"private error content"}'
        exit 60
        ;;
    *'?id=42')
        if [[ "${STUB_MODE:-}" = forbidden ]]; then
            printf '%s\n' '{"status":403,"body":"private error content"}'
            exit 60
        elif [[ "${STUB_MODE:-}" = corrupt ]]; then
            printf '%s\n' 'not a Mach-O file'
        else
            cat "$FIXTURE_DIR/app.dSYM/Contents/Resources/DWARF/app"
        fi
        ;;
    *)
        echo 'Unexpected API endpoint' >&2
        exit 1
        ;;
    esac
    ;;
*)
    echo 'Unexpected sentry command' >&2
    exit 1
    ;;
esac
