import {
  supabase,
  formatCurrency,
  formatDate,
  showToast
} from './supabase.js'

export const initDashboard = async (storeId) => {
  const main = document.getElementById('main-content')

  if (!main) {
    console.error('FARMAKEIA: elemento #main-content não encontrado')
    return
  }

  main.innerHTML = `
    <div class="skeleton-loader">
      Carregando dashboard...
    </div>
  `

  try {
    const [
      salesToday,
      stockSummary,
      expiring,
      financial,
      capital,
      registers
    ] = await Promise.all([
      supabase
        .from('sales')
        .select('total_amount')
        .eq('store_id', storeId)
        .gte(
          'created_at',
          new Date().toISOString().split('T')[0]
        ),

      supabase
        .from('stock_summary')
        .select('*')
        .eq('store_id', storeId),

      supabase
        .from('expiring_products')
        .select('*')
        .eq('store_id', storeId)
        .in('expiry_status', [
          'expired',
          'expiring_30'
        ]),

      supabase
        .from('financial_summary')
        .select('*')
        .eq('store_id', storeId)
        .single(),

      supabase
        .from('capital_transactions')
        .select('amount')
        .eq('store_id', storeId),

      supabase
        .from('cash_registers')
        .select('*')
        .eq('store_id', storeId)
        .eq('status', 'open')
    ])

    // Verifica erros individuais
    if (salesToday.error) {
      console.error('Erro sales:', salesToday.error)
    }

    if (stockSummary.error) {
      console.error('Erro stock_summary:', stockSummary.error)
    }

    if (expiring.error) {
      console.error('Erro expiring_products:', expiring.error)
    }

    if (financial.error) {
      console.error('Erro financial_summary:', financial.error)
    }

    if (capital.error) {
      console.error('Erro capital_transactions:', capital.error)
    }

    if (registers.error) {
      console.error('Erro cash_registers:', registers.error)
    }

    const totalSales =
      salesToday.data?.reduce(
        (sum, sale) =>
          sum + Number(sale.total_amount || 0),
        0
      ) || 0

    const stockCost =
      stockSummary.data?.reduce(
        (sum, stock) =>
          sum + Number(stock.total_cost || 0),
        0
      ) || 0

    const totalCapital =
      capital.data?.reduce(
        (sum, transaction) =>
          sum + Number(transaction.amount || 0),
        0
      ) || 0

    const grossProfit =
      Number(financial.data?.gross_profit || 0)

    const expiringCount =
      expiring.data?.length || 0

    main.innerHTML = `
      <div class="dashboard">

        <h1>Dashboard Administrativo</h1>

        <div
          class="grid"
          style="margin-top:1.5rem"
        >

          <div class="stat-card">
            <div class="stat-value">
              ${formatCurrency(totalSales)}
            </div>

            <div class="stat-label">
              Vendas Hoje
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-value">
              ${formatCurrency(grossProfit)}
            </div>

            <div class="stat-label">
              Lucro Bruto
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-value">
              ${formatCurrency(stockCost)}
            </div>

            <div class="stat-label">
              Estoque a Custo
            </div>
          </div>

          <div class="stat-card">
            <div class="stat-value">
              ${formatCurrency(totalCapital)}
            </div>

            <div class="stat-label">
              Capital Investido
            </div>
          </div>

        </div>

        ${
          expiringCount > 0
            ? `
              <div
                class="card"
                style="
                  margin-top:1.5rem;
                  border-left:4px solid var(--warning)
                "
              >

                <div class="card-title">
                  Alertas de Validade (${expiringCount})
                </div>

                <div
                  class="table-container"
                  style="margin-top:1rem"
                >

                  <table>

                    <thead>
                      <tr>
                        <th>Produto</th>
                        <th>Lote</th>
                        <th>Validade</th>
                        <th>Qtd</th>
                        <th>Status</th>
                      </tr>
                    </thead>

                    <tbody>

                      ${
                        expiring.data
                          .map(
                            product => `
                              <tr>

                                <td>
                                  ${product.product_name || '-'}
                                </td>

                                <td>
                                  ${product.batch_number || '-'}
                                </td>

                                <td>
                                  ${
                                    product.expiry_date
                                      ? formatDate(product.expiry_date)
                                      : '-'
                                  }
                                </td>

                                <td>
                                  ${product.quantity ?? 0}
                                </td>

                                <td>
                                  <span
                                    class="badge badge-${
                                      product.expiry_status ===
                                      'expired'
                                        ? 'danger'
                                        : 'warning'
                                    }"
                                  >
                                    ${
                                      product.expiry_status ===
                                      'expired'
                                        ? 'Vencido'
                                        : 'Vence em 30d'
                                    }
                                  </span>
                                </td>

                              </tr>
                            `
                          )
                          .join('')
                      }

                    </tbody>

                  </table>

                </div>

              </div>
            `
            : ''
        }

      </div>
    `
  } catch (err) {
    console.error(
      'FARMAKEIA - Erro ao carregar dashboard:',
      err
    )

    main.innerHTML = `
      <div
        class="card"
        style="
          margin:2rem;
          padding:2rem;
          text-align:center;
        "
      >
        <h2>Erro ao carregar dashboard</h2>

        <p>
          Não foi possível carregar os dados do dashboard.
        </p>

        <small>
          Verifique o Console do navegador para mais detalhes.
        </small>
      </div>
    `

    showToast(
      'Erro ao carregar dashboard',
      'error'
    )
  }
}
