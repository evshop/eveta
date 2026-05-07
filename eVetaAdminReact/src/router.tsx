import React from 'react';
import { createBrowserRouter } from 'react-router-dom';
import { AppShell } from './ui/AppShell';
import { LoginPage } from './ui/LoginPage';
import { DashboardPage } from './ui/DashboardPage';
import { CategoriesPage } from './ui/CategoriesPage';
import { StoresPage } from './ui/StoresPage';

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'categories', element: <CategoriesPage /> },
      { path: 'stores', element: <StoresPage /> },
    ],
  },
]);

