import { prisma } from '../src/lib/prisma';
prisma.darkStore.findMany().then((stores) => {
  console.log("DARK STORES IN DB:");
  console.log(JSON.stringify(stores, null, 2));
});
