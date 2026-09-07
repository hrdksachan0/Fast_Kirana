import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { auth } from '@/auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const session = await auth();
    const user = session?.user;

    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const email = (user.email || '').toLowerCase().trim();
    const phone = (user as any).phone || '';
    const phoneDigits = phone.replace(/\D/g, '').slice(-10);
    const assignedStoreId = (user as any).assignedStoreId || null;

    const isSuperAdmin =
      email === 'superadmin@fastkirana.com' ||
      email.startsWith('superadmin') ||
      phoneDigits === '9170942500' ||
      (user.role === 'ADMIN' && !assignedStoreId);

    if (!isSuperAdmin) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + istOffset);
    istDate.setUTCHours(0, 0, 0, 0);
    const startOfToday = new Date(istDate.getTime() - istOffset);

    const [
      stores,
      todayAgg,
      todayDeliveredAgg,
      storeWiseSalesRaw,
      staffList,
      staffCount,
    ] = await Promise.all([
      prisma.darkStore.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          _count: { select: { staffMembers: true, orders: true } },
          staffMembers: {
            where: { role: 'ADMIN' },
            select: { id: true, name: true, phone: true, email: true },
            take: 1,
          },
        },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          deliveryMethod: { not: 'RETAIL' },
          status: { not: 'CANCELLED' },
        },
        _sum: { total: true },
        _count: { id: true },
      }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          deliveryMethod: { not: 'RETAIL' },
          status: 'DELIVERED',
        },
        _sum: { total: true },
        _count: { id: true },
      }),
      prisma.$queryRaw<any[]>`
        SELECT "storeId",
               COUNT(id)::int as "orderCount",
               COALESCE(SUM(CASE WHEN status != 'CANCELLED' THEN total ELSE 0 END), 0)::float as "totalSales",
               COALESCE(SUM(CASE WHEN status = 'DELIVERED' THEN total ELSE 0 END), 0)::float as "deliveredSales",
               COUNT(CASE WHEN status NOT IN ('DELIVERED', 'CANCELLED') THEN 1 END)::int as "activeOrders",
               COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END)::int as "deliveredOrders"
        FROM orders
        WHERE "createdAt" >= ${startOfToday}
          AND ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
        GROUP BY "storeId"
      `,
      prisma.user.findMany({
        where: { role: { not: 'USER' } },
        select: {
          id: true,
          name: true,
          phone: true,
          email: true,
          role: true,
          assignedStoreId: true,
          assignedRestaurantId: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.user.count({ where: { role: { not: 'USER' } } }),
    ]);

    const formattedStoreWiseSales = storeWiseSalesRaw.map((row) => {
      const store = stores.find((s) => s.id === row.storeId);
      return {
        ...row,
        storeName: store ? store.name : 'Unassigned',
      };
    });

    const formattedStaffList = staffList.map((s) => {
      const store = stores.find((st) => st.id === s.assignedStoreId);
      return {
        ...s,
        storeName: store ? store.name : (s.assignedStoreId ? s.assignedStoreId : 'Unassigned'),
      };
    });

    return NextResponse.json({
      combined: {
        todaySales: todayAgg._sum.total || 0,
        todayNetRevenue: todayDeliveredAgg._sum.total || 0,
        todayOrders: todayAgg._count.id || 0,
        todayDeliveredOrders: todayDeliveredAgg._count.id || 0,
        totalStaff: staffCount,
        totalStores: stores.length,
      },
      stores: stores.map((s) => ({
        id: s.id,
        name: s.name,
        isActive: s.isActive,
        groceryOpen: s.groceryOpen,
        latitude: s.latitude,
        longitude: s.longitude,
        deliveryRadiusKm: s.deliveryRadiusKm,
        staffCount: s._count.staffMembers,
        orderCount: s._count.orders,
        manager: s.staffMembers?.[0] || null,
      })),
      storeWiseSales: formattedStoreWiseSales,
      staff: formattedStaffList,
    });
  } catch (error) {
    console.error('Error fetching superadmin stats:', error);
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
  }
}
