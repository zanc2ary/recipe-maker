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

      if (!lambdaResponse.ok) {
        throw new Error(`Lambda API error: ${lambdaResponse.status}`);
      }

      const authResult = await lambdaResponse.json();

      if (authResult.success) {
        // Authentication successful
        console.log("Authentication successful for:", email);

        res.json({
          success: true,
          message: "Login successful",
          token: authResult.token,
          user: authResult.user,
        });
      } else {
        // Authentication failed
        console.log("Authentication failed for:", email);

        res.status(401).json({
          success: false,
          message: authResult.message || "Invalid credentials",
        });
      }
    } catch (lambdaError) {
      console.error("Lambda authentication error:", lambdaError);

      // For demo purposes, simulate successful login for specific credentials
      if (email === "demo@recipeai.com" && password === "demo123") {
        console.log("Demo login successful for:", email);

        return res.json({
          success: true,
          message: "Login successful (demo mode)",
          token: "demo-token-" + Date.now(),
          user: {
            id: "demo-user",
            email: email,
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
