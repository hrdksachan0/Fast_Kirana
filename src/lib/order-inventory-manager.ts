export interface OrderInventoryItem {
  productId: string
  name: string
  quantity: number
  selectedVariant?: string | null
}

/**
 * Deducts stock from products, variants, and FIFO/FEFO batches inside a Prisma transaction,
 * creating immutable StockLog audit entries for each deduction.
 * Kitchen/restaurant items (with restaurantId) are skipped automatically.
 */
export async function deductOrderInventory(
  tx: any,
  items: OrderInventoryItem[],
  storeId?: string | null
): Promise<void> {
  for (const item of items) {
    if (!item.productId) continue

    const dbProd = await tx.product.findUnique({
      where: { id: item.productId },
      include: { category: true },
    })

    // Kitchen/restaurant items are cooked on demand and do not have darkstore inventory
    if (dbProd && dbProd.restaurantId) {
      continue
    }

    if (item.selectedVariant) {
      // 1. Variant stock deduction from product.variants JSON array
      if (dbProd && dbProd.variants && Array.isArray(dbProd.variants)) {
        const prevStock = dbProd.stock
        const updatedVariants = (dbProd.variants as any[]).map((v) => {
          if (v.name === item.selectedVariant) {
            return { ...v, stock: Math.max(0, v.stock - item.quantity) }
          }
          return v
        })
        const newTotalStock = updatedVariants.reduce((sum, v) => sum + (v.stock || 0), 0)

        await tx.product.update({
          where: { id: item.productId },
          data: {
            variants: updatedVariants,
            stock: newTotalStock,
          },
        })

        await tx.stockLog.create({
          data: {
            productId: item.productId,
            quantity: -item.quantity,
            type: 'ONLINE_ORDER',
            prevStock,
            newStock: newTotalStock,
          },
        }).catch((logErr: any) => console.error('Failed to write variant stock log:', logErr))
      }
    } else {
      // 2. Standard batch-aware (FIFO/FEFO) deduction
      const batches = await tx.productBatch.findMany({
        where: {
          productId: item.productId,
          quantity: { gt: 0 },
        },
        orderBy: {
          expiryDate: 'asc',
        },
      })

      let remainingToDeduct = item.quantity

      if (batches.length > 0) {
        for (const batch of batches) {
          if (remainingToDeduct <= 0) break
          const deductFromThisBatch = Math.min(batch.quantity, remainingToDeduct)
          await tx.productBatch.update({
            where: { id: batch.id },
            data: { quantity: { decrement: deductFromThisBatch } },
          })
          remainingToDeduct -= deductFromThisBatch
        }
      }

      const activeBatches = await tx.productBatch.findMany({
        where: {
          productId: item.productId,
          quantity: { gt: 0 },
        },
        orderBy: { expiryDate: 'asc' },
      })

      const prevStock = dbProd ? dbProd.stock : 0
      const newTotalStock = activeBatches.length > 0
        ? activeBatches.reduce((sum: number, b: any) => sum + b.quantity, 0)
        : Math.max(0, prevStock - item.quantity)
      const newEarliestExpiry = activeBatches.length > 0 ? activeBatches[0].expiryDate : null

      if (activeBatches.length > 0 || batches.length > 0) {
        await tx.product.update({
          where: { id: item.productId },
          data: {
            stock: newTotalStock,
            expiryDate: newEarliestExpiry,
          },
        })
      } else {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } },
        })
      }

      await tx.stockLog.create({
        data: {
          productId: item.productId,
          quantity: -item.quantity,
          type: 'ONLINE_ORDER',
          prevStock,
          newStock: newTotalStock,
        },
      }).catch((logErr: any) => console.error('Failed to write batch stock log:', logErr))
    }

    // 3. Localized Store Inventory deduction (if storeId is provided)
    if (storeId) {
      try {
        const existingStoreInv = await tx.storeInventory.findUnique({
          where: {
            productId_storeId: {
              productId: item.productId,
              storeId: storeId,
            }
          }
        })

        if (existingStoreInv) {
          await tx.storeInventory.update({
            where: {
              productId_storeId: {
                productId: item.productId,
                storeId: storeId,
              }
            },
            data: {
              stock: { decrement: item.quantity }
            }
          })
        }
      } catch (storeInvErr) {
        console.warn(`Could not decrement localized StoreInventory for product ${item.productId} at store ${storeId}:`, storeInvErr)
      }
    }
  }
}
