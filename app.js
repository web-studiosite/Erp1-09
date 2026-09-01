import {
  supabase,
  getProfile,
  signOut,
  formatCurrency,
  showToast
} from './supabase.js'

import { initAuth } from './auth.js'

let currentProfile = null
let currentStoreId = null

export const initApp = async () => {
  try {
    currentProfile = await initAuth()

    if (!currentProfile) {
      return
    }

    currentStoreId = currentProfile.store_id

    setupNavigation()
    renderLayout()

    if (currentProfile.role === 'admin') {
      const { initDashboard } = await import('./dashboard.js')
      await initDashboard(currentStoreId)
    } else {
      const { initCashierDashboard } = await import('./cashier.js')
      await initCashierDashboard(currentStoreId)
    }

  } catch (err) {
    console.error('Erro ao iniciar FARMAKEIA:', err)
    showToast('Erro ao iniciar o sistema', 'error')
  }
}


const setupNavigation = () => {

  document.addEventListener('click', (e) => {

    const link = e.target.closest('[data-nav]')

    if (!link) {
      return
    }

    e.preventDefault()

    const page = link.dataset.nav

    navigateTo(page)
  })
}


const navigateTo = async (page) => {

  const main = document.getElementById('main-content')

  if (!main) {
    return
  }

  main.innerHTML = `
    <div class="skeleton-loader">
      Carregando...
    </div>
  `

  try {

    if (page === 'dashboard') {

      const { initDashboard } =
        await import('./dashboard.js')

      await initDashboard(currentStoreId)

    }

    else if (page === 'sales') {

      const { initSales } =
        await import('./sales.js')

      await initSales(currentStoreId)

    }

    else if (page === 'warehouse') {

      const { initWarehouse } =
        await import('./warehouse.js')

      await initWarehouse(currentStoreId)

    }

    else if (page === 'inventory') {

      const { initInventory } =
        await import('./inventory.js')

      await initInventory(currentStoreId)

    }

    else if (page === 'products') {

      const { initProducts } =
        await import('./products.js')

      await initProducts(currentStoreId)

    }

    else if (page === 'cashier') {

      const { initCashierDashboard } =
        await import('./cashier.js')

      await initCashierDashboard(currentStoreId)

    }

    else if (page === 'finance') {

      const { initFinance } =
        await import('./finance.js')

      await initFinance(currentStoreId)

    }

    else if (page === 'reports') {

      const { initReports } =
        await import('./reports.js')

      await initReports(currentStoreId)

    }

    else if (page === 'audit') {

      const { initAudit } =
        await import('./audit.js')

      await initAudit(currentStoreId)

    }

    else if (page === 'settings') {

      const { initSettings } =
        await import('./settings.js')

      await initSettings(currentStoreId)

    }

    else if (page === 'admin') {

      const { initAdmin } =
        await import('./admin.js')

      await initAdmin(currentStoreId)

    }

  } catch (err) {

    console.error(
      `Erro ao carregar página "${page}":`,
      err
    )

    showToast(
      'Erro ao carregar pagina',
      'error'
    )
  }
}


const renderLayout = () => {

  const app = document.getElementById('app')

  if (!app) {
    console.error('Elemento #app não encontrado')
    return
  }

  const isAdminRole =
    currentProfile.role === 'admin'

  app.innerHTML = `

    <div class="app-layout">

      <aside class="sidebar">

        <div class="sidebar-brand">

          <h2>FARMAKEIA</h2>

          <span>
            ${currentProfile.full_name || ''}
          </span>

        </div>


        <nav class="sidebar-nav">

          ${
            isAdminRole

              ? `

                <a
                  href="#"
                  data-nav="dashboard"
                  class="nav-item"
                >
                  <span>Dashboard</span>
                  Dashboard
                </a>

                <a
                  href="#"
                  data-nav="sales"
                  class="nav-item"
                >
                  <span>Vendas</span>
                  Vendas
                </a>

                <a
                  href="#"
                  data-nav="warehouse"
                  class="nav-item"
                >
                  <span>Armazem</span>
                  Armazem
                </a>

                <a
                  href="#"
                  data-nav="inventory"
                  class="nav-item"
                >
                  <span>Estoque</span>
                  Estoque
                </a>

                <a
                  href="#"
                  data-nav="products"
                  class="nav-item"
                >
                  <span>Produtos</span>
                  Produtos
                </a>

                <a
                  href="#"
                  data-nav="finance"
                  class="nav-item"
                >
                  <span>Financeiro</span>
                  Financeiro
                </a>

                <a
                  href="#"
                  data-nav="reports"
                  class="nav-item"
                >
                  <span>Relatorios</span>
                  Relatorios
                </a>

                <a
                  href="#"
                  data-nav="audit"
                  class="nav-item"
                >
                  <span>Auditoria</span>
                  Auditoria
                </a>

                <a
                  href="#"
                  data-nav="settings"
                  class="nav-item"
                >
                  <span>Configuracoes</span>
                  Configuracoes
                </a>

                <a
                  href="#"
                  data-nav="admin"
                  class="nav-item"
                >
                  <span>Usuarios</span>
                  Usuarios
                </a>

              `

              : `

                <a
                  href="#"
                  data-nav="dashboard"
                  class="nav-item"
                >
                  <span>Caixa</span>
                  Meu Caixa
                </a>

                <a
                  href="#"
                  data-nav="sales"
                  class="nav-item"
                >
                  <span>Vender</span>
                  Nova Venda
                </a>

                <a
                  href="#"
                  data-nav="cashier"
                  class="nav-item"
                >
                  <span>Sangria</span>
                  Caixa / Sangria
                </a>

              `
          }


          <button
            id="btnLogout"
            type="button"
            class="nav-item logout"
          >
            <span>Sair</span>
            Sair
          </button>

        </nav>

      </aside>


      <main
        id="main-content"
        class="main-content"
      ></main>

    </div>
  `


  const logoutButton =
    document.getElementById('btnLogout')

  if (logoutButton) {

    logoutButton.addEventListener(
      'click',
      signOut
    )

  }
}


initApp()
