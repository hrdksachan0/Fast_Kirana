import { notFound } from 'next/navigation'
import Link from 'next/link'
import { prisma } from '@/lib/prisma'
import { ProductScrollSection } from '@/components/product/product-scroll-section'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion'
import { Star, Truck, ShieldCheck, Heart, Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag } from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { ProductVariantSelector } from '@/components/product/product-variant-selector'

const iconMap: Record<string, React.ComponentType<any>> = {
  'fruits-vegetables': Salad,
  'dairy-breakfast': Milk,
  'snacks-munchies': Cookie,
  'beverages': CupSoda,
  'personal-care': Sparkles,
  'household': Home,
  'bakery-biscuits': Croissant,
  'atta-rice-dal': Wheat,
}
import { Product } from '@/types'
import { cn } from '@/lib/utils'

interface ProductPageProps {
  params: Promise<{ slug: string }>
}

export const revalidate = 60

export default async function ProductPage({ params }: ProductPageProps) {
  const { slug } = await params

  // 1. Fetch the active product
  const productRaw = await prisma.product.findUnique({
    where: { slug },
    include: {
      category: true,
      images: true,
      reviews: {
        include: {
          user: {
            select: {
              name: true,
              image: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
      },
    },
  }).catch(() => null)

  if (!productRaw) {
    notFound()
  }

  // 2. Fetch related products in the same category
  const relatedRaw = await prisma.product.findMany({
    where: {
      categoryId: productRaw.categoryId,
      id: { not: productRaw.id },
      isAvailable: true,
    },
    take: 8,
    include: {
      category: true,
    },
  }).catch(() => [])

  // Map to UI types
  const mapProduct = (p: any): Product => ({
    id: p.id,
    name: p.name,
    slug: p.slug,
    description: p.description,
    imageUrl: p.imageUrl,
    categoryId: p.categoryId,
    mrp: p.mrp,
    price: p.price,
    discount: p.discount,
    unit: p.unit,
    stock: p.stock,
    isAvailable: p.isAvailable,
    tags: p.tags,
    variants: p.variants,
    category: p.category ? {
      id: p.category.id,
      name: p.category.name,
      slug: p.category.slug,
      imageUrl: p.category.imageUrl,
      parentId: p.category.parentId,
      sortOrder: p.category.sortOrder,
    } : undefined,
  })

  const product = mapProduct(productRaw)
  const relatedProducts = relatedRaw.map(mapProduct)

  // Average rating calculation

  // Calculate average rating
  const reviewCount = productRaw.reviews.length
  const avgRating = reviewCount > 0
    ? (productRaw.reviews.reduce((sum, r) => sum + r.rating, 0) / reviewCount).toFixed(1)
    : null

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl space-y-6 md:space-y-10">
      
      {/* Breadcrumbs */}
      <nav className="text-xs font-bold text-text-secondary flex items-center gap-1.5 px-1">
        <Link href="/" className="hover:text-primary transition-colors">Home</Link>
        <span>/</span>
        {product.category && (
          <>
            <Link 
              href={product.category.slug === 'cafe' ? '/cafe' : `/category/${product.category.slug}`} 
              className="hover:text-primary transition-colors"
            >
              {product.category.name}
            </Link>
            <span>/</span>
          </>
        )}
        <span className="text-text-primary line-clamp-1">{product.name}</span>
      </nav>

      {/* Main product details section */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-8 lg:gap-12 bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm">
        
        {/* Left Column: Image and Badges */}
        <div className="flex flex-col gap-4">
          <div className="relative aspect-square w-full rounded-2xl border border-border/40 bg-muted/20 flex items-center justify-center overflow-hidden group">
            {product.discount > 0 && (
              <span className="absolute left-4 top-4 z-10 bg-discount px-3 py-1 text-xs font-extrabold text-white rounded-lg shadow-sm animate-bounce-subtle">
                {product.discount}% OFF
              </span>
            )}
            
            <ProductImage
              src={product.imageUrl}
              alt={product.name}
              categorySlug={product.category?.slug}
              className="h-full w-full object-contain p-2 min-[375px]:p-4 md:p-6 transition-transform duration-300 group-hover:scale-105"
            />
          </div>
        </div>

        {/* Right Column: Information & Actions */}
        <div className="flex flex-col justify-between space-y-4 md:space-y-6">
          <div className="space-y-3 md:space-y-4">
            {/* Category tag */}
            {product.category && (
              <span className="inline-block text-[10px] font-extrabold uppercase tracking-wider text-primary bg-primary/10 px-2.5 py-1 rounded-full">
                {product.category.name}
              </span>
            )}

            {/* Name */}
            <h1 className="text-xl min-[375px]:text-2xl md:text-3xl font-bold md:font-extrabold text-text-primary tracking-tight leading-tight">
              {product.name}
            </h1>

            {/* Unit & Ratings summary */}
            <div className="flex items-center gap-4 text-sm font-semibold">
              <span className="text-text-secondary bg-muted px-2.5 py-1 rounded-lg">
                {product.unit}
              </span>
              
              {avgRating && (
                <div className="flex items-center gap-1 text-amber-500">
                  <Star className="h-4 w-4 fill-current" />
                  <span>{avgRating}</span>
                  <span className="text-text-secondary font-medium">({reviewCount} reviews)</span>
                </div>
              )}
            </div>

            {/* Price list, variants, banners, stock alerts and dynamic action controls */}
            <ProductVariantSelector product={product} />
          </div>

          {/* Product description & collapsible details */}
          <div className="pt-4 border-t border-border/40">
            <Accordion className="w-full">
              <AccordionItem value="description" className="border-border/60">
                <AccordionTrigger className="text-sm font-bold hover:text-primary">
                  Product Description
                </AccordionTrigger>
                <AccordionContent className="text-xs text-text-secondary leading-relaxed">
                  {product.description || "Fresh and premium quality products sourced from local farms and trusted distributors. Order now and get instant delivery."}
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="storage" className="border-border/60">
                <AccordionTrigger className="text-sm font-bold hover:text-primary">
                  Storage & Care
                </AccordionTrigger>
                <AccordionContent className="text-xs text-text-secondary leading-relaxed">
                  Keep in a cool and dry place. For fresh fruits and vegetables, refrigerate immediately to maintain freshness and crispness. Wash thoroughly before use.
                </AccordionContent>
              </AccordionItem>
              <AccordionItem value="seller" className="border-border/60">
                <AccordionTrigger className="text-sm font-bold hover:text-primary">
                  Seller Information
                </AccordionTrigger>
                <AccordionContent className="text-xs text-text-secondary leading-relaxed">
                  Sold and fulfilled directly by FastKirana local dark stores. All products are verified for freshness and authentic expiry dates.
                </AccordionContent>
              </AccordionItem>
            </Accordion>
          </div>

        </div>
      </div>

      {/* Related Products horizontal scroll */}
      {relatedProducts.length > 0 && (
        <ProductScrollSection
          title="Related Products"
          subtitle="Customer favorites in this category"
          products={relatedProducts}
        />
      )}

      {/* Reviews Details list */}
      <section className="bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-4 md:space-y-6">
        <h2 className="text-lg md:text-xl font-bold text-text-primary tracking-tight border-b border-border/40 pb-3">
          Customer Reviews
        </h2>
        
        {productRaw.reviews.length === 0 ? (
          <div className="py-10 text-center flex flex-col items-center">
            <Star className="h-10 w-10 text-text-muted stroke-[1.2] mb-2" />
            <p className="text-xs font-semibold text-text-secondary">No reviews yet for this product.</p>
            <p className="text-[10px] text-text-muted mt-0.5">Be the first to order and review this item!</p>
          </div>
        ) : (
          <div className="space-y-4 division-y divide-border/40">
            {productRaw.reviews.map((review) => (
              <div key={review.id} className="pt-4 first:pt-0 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-xs">
                      {review.user.name?.charAt(0) || 'U'}
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-text-primary">{review.user.name || "Verified Customer"}</h4>
                      <div className="flex gap-0.5 mt-0.5">
                        {[...Array(5)].map((_, i) => (
                          <Star
                            key={i}
                            className={cn(
                              "h-3 w-3",
                              i < review.rating ? "fill-amber-500 text-amber-500" : "text-muted"
                            )}
                          />
                        ))}
                      </div>
                    </div>
                  </div>
                  <span className="text-[10px] text-text-muted">
                    {new Date(review.createdAt).toLocaleDateString('en-IN', {
                      day: 'numeric',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </span>
                </div>
                {review.comment && (
                  <p className="text-xs text-text-secondary leading-relaxed pl-10">
                    {review.comment}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </section>

    </div>
  )
}
