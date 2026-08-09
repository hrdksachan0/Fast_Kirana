'use client'

import Image from 'next/image'
import { motion } from 'framer-motion'

const EDITORIAL_BANNERS = [
  {
    id: 'b1',
    tag: 'MICHELIN STARRED',
    title: 'The Tasting Menu',
    subtitle: 'Curated experiences delivered.',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD_ZtZ5AFxDNkXc6DM3c7LFS7yhT7FbmtJWXbdi6dVpYEOt_X5B4LNzxX_8Kif4vLZtBDcjOZNlaEDOCf0cn9blz8nM-FQDUYCP4OI6c7Ykazrr4CwQq_Ukws8S76EsfhFabGM8FTtKU4hU5TPlNedEC8SC9R_rdxvY7kyoze_UyGBW6O-lzqSgle_mtKmJk2hqOGJo9eCG0vUytuUr0lFLnyyq_kf4TLtF6YoLaPf-nKT4Ev-nf_tLZQ',
  },
  {
    id: 'b2',
    tag: 'NEW ARRIVAL',
    title: 'Sushi Masterclass',
    subtitle: 'Direct from Omotenashi.',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCOysdCGB-yLxHOeKTwh3f65j8ITYAMdj_5FdRFW2NxHMmh_Th249nJ_Fc1GglNE7T8BFwTi5oqxykmE4K9ec3bDHNAB-igNUp5FRq3C5eUKnO5rT9UJUz3oQ8pHjH2vgzUqUyQXklRTQrKnAEZfd57oZu7n4YuPq36DwTixm5KcyK00aeEzmzmu-gL_jtafWKX_2DgUL8ujB5qglxpP5KzzSydbhWhtBeizl7QJIiydTTk5Kunb1_wmQ',
  },
]

const GOURMET_CATEGORIES = [
  {
    id: 'c1',
    title: 'Artisan Bakery',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB-ZPZyaXx-zRpUvOt0LsP93QoUCDVb6DYNf_HsIbZYWUVr2n9XBnH4eqnpk3Gi9-EZv8mcNGDVnGx8xtQUE78_zqNKA7tte5wU6g3E-AyjzhpwuWdGhCP-s--XbZV7mb7nGeiGaVV1LRl2TetN0nx0-CqoWEoR81dS42bzgBLPghs8cUW3FtPd_g9EAtpCYmV2MQS-HtYIr5LP2p-jM7kfBFJ5At7A7MzJYIMJ2UoRcR2_y90BIX3OFA',
  },
  {
    id: 'c2',
    title: 'Cheese & Meat',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAEGCqhCAjyA74S6TcSynXzFVugjnExan72AJvbwe_fEZX33RVYHM_V1vMq2rf3Xkkauw3yeP511gN_HFrETkrhdQXJKD60Zei6jAQjk-YGIz6YeSeqBhvvspDFhf3dNtuobTqna985-8U7646Xd54a0-RgroXFMHnQtrR5ig1TlKFhN6xvWq4WKbeNIkwBvD4_p5xOOxGkwzMnI3cjCnbMQknu1oCviQdUys_7pZqzgO5oxWupKThGiA',
  },
  {
    id: 'c3',
    title: 'Café Elite',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCKw_bVU_RzroNTk3YSj1gW4v7bjNjjg5pL0X--aXYrURT32RffSwr9Zcyh8-9aDYVAggwujWw3KJWqzhDGVtCl9eDC-uWi1n4Uh75foPQK_8B_ma8Q1ZxOQBuPXLAbikOMdlKP5g-ALihnP_3wpiTzszP3sSqy5CXnnE-_3yhPLJQnwFSnkkuSNyNrCKr-xL_dCUFz-fmScj8MOSsIKlFSLtSD_ng4I9AosZbY-ttvDFFsrM9Ic6nWRg',
  },
  {
    id: 'c4',
    title: 'Healthy Luxe',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCZYaeJTUZgVB57e7gwHo6wcvP_5itQ6qguzxgYJKF3Y1nykTJG15yai06ex-_2h9XlN46oSVz1T-JP2TZxOupy_0N1EQgf9kdVaWSv-wKxOlv74MR5v736561tTbb-R9OL74NlHc5-5O0J5GX1N0NwbdrmRabL3rauvFnwqmEaFNiYKHFgkwTgyN302rxIM1vTfYhIRo7BUZc3fmPf_QXla_gSOPkyd8fQtMRdOB2CP1WhtkDW57jFZA',
  },
  {
    id: 'c5',
    title: 'Dessert Bar',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAIJPjF1weNGEGC1X584-pC4ajDd5TsewVUBYHoBgBZePsgBI_MU5ZekYmkKgSWXLFhctV0selP8q3QW3QXQVaoidVp7cYxrg_Ja-uvFzuO8X4k4efcmntNop4P5FOjcOpFENFGNzX4tCsTJ9bgjvvJQzbFivXouHlOskQUb1jLaA3sdoBMi5Xcap4yjujI8YIF6xLXm_ytY8ygEJ9EQSulrA4Phh2id9PjuvgTC-4YuWvwVekv_946qQ',
  },
]

export function FoodEditorialCuration() {
  return (
    <div className="w-full flex flex-col gap-6 select-none">
      {/* 1. Editorial Banners Horizontal Scroll */}
      <div className="w-full overflow-x-auto scrollbar-none pb-2">
        <div className="flex gap-4 min-w-max">
          {EDITORIAL_BANNERS.map((banner) => (
            <motion.div
              key={banner.id}
              whileHover={{ scale: 1.02 }}
              transition={{ duration: 0.2 }}
              className="relative w-[300px] sm:w-[360px] h-[180px] sm:h-[200px] rounded-2xl overflow-hidden shadow-xs shrink-0 bg-zinc-900 border border-zinc-200/40 dark:border-zinc-800"
            >
              <Image
                src={banner.image}
                alt={banner.title}
                fill
                className="object-cover"
                sizes="(max-width: 640px) 300px, 360px"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-transparent flex flex-col justify-end p-4 sm:p-5">
                <span className="text-[11px] font-black uppercase tracking-wider text-red-300 mb-1">
                  {banner.tag}
                </span>
                <h3 className="text-xl sm:text-2xl font-black text-white leading-tight">
                  {banner.title}
                </h3>
                <p className="text-xs sm:text-sm text-zinc-300 font-medium mt-1">
                  {banner.subtitle}
                </p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* 2. Gourmet Curation Categories */}
      <div className="flex flex-col gap-3">
        <h2 className="text-lg sm:text-xl font-extrabold text-zinc-900 dark:text-zinc-100 tracking-tight">
          Gourmet Curation
        </h2>
        <div className="flex gap-5 sm:gap-6 overflow-x-auto scrollbar-none pb-2 pt-1 items-start min-w-max">
          {GOURMET_CATEGORIES.map((cat) => (
            <motion.div
              key={cat.id}
              whileHover={{ y: -3 }}
              className="flex flex-col items-center gap-2 w-[72px] shrink-0 cursor-pointer"
            >
              <div className="relative w-[64px] h-[64px] rounded-full overflow-hidden shadow-xs border-2 border-zinc-200 dark:border-zinc-700 bg-zinc-100 dark:bg-zinc-800">
                <Image
                  src={cat.image}
                  alt={cat.title}
                  fill
                  className="object-cover"
                  sizes="64px"
                />
              </div>
              <span className="text-[12px] font-semibold text-zinc-800 dark:text-zinc-200 text-center leading-tight">
                {cat.title}
              </span>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}
