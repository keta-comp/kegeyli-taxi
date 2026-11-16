import React from 'react';
import {createRoot} from 'react-dom/client';
import App from './App';
import PWAUpdateNotice from './PWAUpdateNotice';
import './styles.css';
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/><PWAUpdateNotice/></React.StrictMode>);