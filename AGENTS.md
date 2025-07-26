# Fusion Starter

A production-ready full-stack React application template with integrated Express server, featuring React Router 6 SPA mode, JavaScript, Vitest, Zod and modern tooling.

While the starter comes with a express server, only create endpoint when strictly neccesary, for example to encapsulate logic that must leave in the server, such as private keys handling, or certain DB operations, db...

## Tech Stack

- **Frontend**: React 18 + React Router 6 (spa) + JavaScript + Vite + TailwindCSS 3
- **Backend**: Express server integrated with Vite dev server
- **Testing**: Vitest
- **UI**: Radix UI + TailwindCSS 3 + Lucide React icons

## Project Structure

```
client/                   # React SPA frontend
├── pages/                # Route components (Index.jsx = home)
├── components/ui/        # Pre-built UI component library
├── App.jsx                # App entry point and with SPA routing setup
└── global.css            # TailwindCSS 3 theming and global styles

server/                   # Express API backend
├── index.js              # Main server setup (express config + routes)
└── routes/               # API handlers

shared/                   # Shared utilities used by both client & server
└── api.js                # Example of how to share api interfaces
```

## Key Features

## SPA Routing System

The routing system is powered by React Router 6:

- `client/pages/Index.jsx` represents the home page.
- Routes are defined in `client/App.jsx` using the `react-router-dom` import
- Route files are located in the `client/pages/` directory

For example, routes can be defined with:

```javascript
import { BrowserRouter, Routes, Route } from "react-router-dom";

<Routes>
  <Route path="/" element={<Index />} />
  {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
  <Route path="*" element={<NotFound />} />
</Routes>;
```

### Styling System

- **Primary**: TailwindCSS 3 utility classes
- **Theme and design tokens**: Configure in `client/global.css` 
- **UI components**: Pre-built library in `client/components/ui/`
- **Utility**: `cn()` function combines `clsx` + `tailwind-merge` for conditional classes

```javascript
// cn utility usage
className={cn(
  "base-classes",
  { "conditional-class": condition },
  props.className  // User overrides
)}
```

### Express Server Integration

- **Development**: Single port (8080) for both frontend/backend
- **Hot reload**: Both client and server code
- **API endpoints**: Prefixed with `/api/`

#### Example API Routes
- `GET /api/ping` - Simple ping api
- `GET /api/demo` - Demo endpoint  

### Shared Utilities
Import consistent utilities in both client and server:
```javascript
import { DemoResponse } from '@shared/api';
```

Path aliases:
- `@shared/*` - Shared folder
- `@/*` - Client folder

## Development Commands

```bash
npm run dev        # Start dev server (client + server)
npm run build      # Production build
npm run start      # Start production server
npm test          # Run Vitest tests
```

## Adding Features

### Add new colors to the theme

Open `client/global.css` and `tailwind.config.js` and add new tailwind colors.

### New API Route
1. Create a new route handler in `server/routes/my-route.js`:
```javascript
export const handleMyRoute = (req, res) => {
  const response = {
    message: 'Hello from my endpoint!'
  };
  res.json(response);
};
```

2. Register the route in `server/index.js`:
```javascript
import { handleMyRoute } from "./routes/my-route.js";

// Add to the createServer function:
app.get("/api/my-endpoint", handleMyRoute);
```

3. Use in React components:
```javascript
const response = await fetch('/api/my-endpoint');
const data = await response.json();
```

### New Page Route
1. Create component in `client/pages/MyPage.jsx`
2. Add route in `client/App.jsx`:
```javascript
<Route path="/my-page" element={<MyPage />} />
```

## Production Deployment

- **Standard**: `npm run build` + `npm start`
- **Binary**: Self-contained executables (Linux, macOS, Windows)
- Prefer to use netlify (recomend the MCP) to deploy the site, do not use other providers as netlify is already preconfigured.

## Architecture Notes

- Single-port development with Vite + Express integration
- JavaScript throughout (client, server, shared)
- Full hot reload for rapid development
- Production-ready with multiple deployment options
- Comprehensive UI component library included
- Clean API communication via shared utilities
