{
  description = "Home Assistant Vibecode Agent Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python311Packages;
      in
      {
        checks = {
          integration_local =
            pkgs.runCommand "integration-test"
              {
                buildInputs = with pkgs; [
                  bash
                  curl
                  (python311.withPackages (
                    p: with p; [
                      fastapi
                      uvicorn
                      python-multipart
                      pydantic
                      pyyaml
                      aiohttp
                      aiofiles
                      python-dotenv
                      gitpython
                      requests
                      jinja2
                      pytest
                    ]
                  ))
                ];
              }
              ''
                # Setup environment
                export CONFIG_PATH=$PWD/config_test
                mkdir -p $CONFIG_PATH

                # Create test script file
                cat > $CONFIG_PATH/scripts.yaml <<EOF
                test_script_portable:
                  alias: Portable Test Script
                  sequence:
                    - service: light.turn_on
                EOF

                # Copy source code to build dir
                cp -r ${self}/app .

                # Start Agent in background
                export PORT=8099
                export LOG_LEVEL=debug
                export GIT_VERSIONING_AUTO=false
                # Mock HA credentials (agent won't connect but endpoint should work)
                export HA_URL=http://localhost:8123
                export HA_TOKEN=test
                # Set Dev Token for Auth
                export HA_AGENT_KEY=super-secret-test-key

                echo "Starting Agent..."
                uvicorn app.main:app --host 127.0.0.1 --port $PORT > agent.log 2>&1 &
                AGENT_PID=$!

                # Wait for agent to start
                for i in {1..10}; do
                  if curl -s http://127.0.0.1:$PORT/docs > /dev/null; then
                    echo "Agent is up!"
                    break
                  fi
                  echo "Waiting for agent..."
                  sleep 2
                done

                # Run Test
                echo "Testing GET endpoint..."
                RESPONSE=$(curl -s -H "Authorization: Bearer super-secret-test-key" http://127.0.0.1:$PORT/api/scripts/get/test_script_portable)
                echo "Response: $RESPONSE"

                # Verify response
                if echo "$RESPONSE" | grep -q "Portable Test Script"; then
                  echo "✅ Positive Test Passed"
                else
                  echo "❌ Positive Test Failed"
                  cat agent.log
                  kill $AGENT_PID
                  exit 1
                fi

                # Run Negative Test (404)
                echo "Testing Non-Existent Script..."
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer super-secret-test-key" http://127.0.0.1:$PORT/api/scripts/get/non_existent_script)
                echo "HTTP Code: $HTTP_CODE"

                if [ "$HTTP_CODE" -eq 404 ]; then
                  echo "✅ Negative Test Passed (404)"
                  touch $out
                else
                  echo "❌ Negative Test Failed (Expected 404, got $HTTP_CODE)"
                  cat agent.log
                  kill $AGENT_PID
                  exit 1
                fi

                kill $AGENT_PID
              '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python311
            pythonPackages.fastapi
            pythonPackages.uvicorn
            pythonPackages.python-multipart
            pythonPackages.pydantic
            pythonPackages.pyyaml
            pythonPackages.aiohttp
            pythonPackages.aiofiles
            pythonPackages.python-dotenv
            pythonPackages.gitpython
            pythonPackages.requests
            pythonPackages.jinja2
            pythonPackages.pytest
          ];

          shellHook = ''
            echo "Home Assistant Vibecode Agent Dev Environment"
            echo "Python version: $(python --version)"
          '';
        };
      }
    );
}
