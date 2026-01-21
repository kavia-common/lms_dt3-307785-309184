import React from 'react';
import { createRoot } from 'react-dom/client';

const App = () => React.createElement('div', null, 'Hello from WebAppFrontend');

createRoot(document.getElementById('root')).render(React.createElement(App));
