// Authentication API routes
const handleLogin = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });
    }

    console.log("Login attempt for:", username);

    // --- Call your Lambda authentication function here ---
    try {
      const lambdaResponse = await fetch("https://0ectiuhd8a.execute-api.ap-southeast-2.amazonaws.com/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ username, password }),
      });

      if (lambdaResponse.ok) {
        // Lambda authentication successful
        console.log("Authentication successful for:", username);

        // Try to parse the response
        try {
          const authResult = await lambdaResponse.json();
          res.json({
            success: true,
            message: "Login successful",
            token: authResult.token || "lambda-token-" + Date.now(),
            user: authResult.user || { username: username, name: "User" }
          });
        } catch (parseError) {
          // If parsing fails, still return success
          res.json({
            success: true,
            message: "Login successful",
            token: "lambda-token-" + Date.now(),
            user: { username: username, name: "User" }
          });
        }
      } else {
        // Authentication failed
        console.log("Authentication failed for:", username, "Status:", lambdaResponse.status);

        res.status(401).json({
          success: false,
          message: "Invalid username or password",
        });
      }
    } catch (lambdaError) {
      console.error("Lambda authentication error:", lambdaError);

      // For demo purposes, simulate successful login for specific credentials
      if (username === "demouser" && password === "demo123") {
        console.log("Demo login successful for:", username);

        return res.json({
          success: true,
          message: "Login successful (demo mode)",
          token: "demo-token-" + Date.now(),
          user: {
            id: "demo-user",
            username: username,
            name: "Demo Chef",
          },
        });
      }

      // Return authentication failure
      res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error during authentication",
    });
  }
};

const handleLogout = async (req, res) => {
  try {
    // Handle logout logic here
    // For example, invalidate tokens, clear sessions, etc.

    res.json({
      success: true,
      message: "Logout successful",
    });
  } catch (error) {
    console.error("Logout error:", error);
    res.status(500).json({
      success: false,
      message: "Error during logout",
    });
  }
};

export { handleLogin, handleLogout };
