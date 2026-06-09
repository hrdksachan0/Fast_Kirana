import React from 'react'

interface LogoProps {
  className?: string
  showText?: boolean
  lightMode?: boolean
  simple?: boolean
}

export function Logo({ className = '', showText = true, lightMode = false, simple = false }: LogoProps) {
  if (simple) {
    return (
      <svg
        viewBox="0 0 140 120"
        className={`h-9 w-auto shrink-0 ${className}`}
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        {/* Left speed lines */}
        <rect x="8" y="44" width="22" height="6.5" rx="3.25" fill="#e20a22" />
        <rect x="0.5" y="58" width="29.5" height="6.5" rx="3.25" fill="#e20a22" />
        <rect x="8" y="72" width="22" height="6.5" rx="3.25" fill="#e20a22" />
        <circle cx="2" cy="61.25" r="3" fill="#e20a22" />

        {/* Main red container square */}
        <rect x="25" y="10" width="100" height="100" rx="28" fill="#e20a22" />

        {/* Clean bold italic sans-serif block F in white */}
        <path
          d="M 62 32 H 98 L 95 46 H 75.5 L 73.4 56 H 89 L 86.5 68 H 71 L 66.8 88 H 50.2 Z"
          fill="white"
        />
      </svg>
    )
  }
  return (
    <div className={`flex items-center gap-2 select-none ${className}`}>
      {/* Red Badge Icon with Speed Lines and Custom Bold F */}
      <svg
        viewBox="0 0 140 120"
        className="h-9 w-auto shrink-0"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        {/* Left speed lines */}
        <rect x="8" y="44" width="22" height="6.5" rx="3.25" fill="#e20a22" />
        <rect x="0.5" y="58" width="29.5" height="6.5" rx="3.25" fill="#e20a22" />
        <rect x="8" y="72" width="22" height="6.5" rx="3.25" fill="#e20a22" />
        <circle cx="2" cy="61.25" r="3" fill="#e20a22" />

        {/* Main red container square */}
        <rect x="25" y="10" width="100" height="100" rx="28" fill="#e20a22" />

        {/* Clean bold italic sans-serif block F in white */}
        <path
          d="M 62 32 H 98 L 95 46 H 75.5 L 73.4 56 H 89 L 86.5 68 H 71 L 66.8 88 H 50.2 Z"
          fill="white"
        />
      </svg>

      {/* Text Branding */}
      {showText && (
        <div className="flex flex-col text-left leading-none">
          <span className="text-xl font-black tracking-tight select-none">
            <span className="text-[#e20a22]">Fast</span>
            <span className={`dark:text-zinc-200 ${lightMode ? 'text-white' : 'text-[#7c0617]'}`}>Kirana</span>
          </span>
          <div className="flex items-center mt-0.5">
            {/* Clean green delivery bag with speed lines */}
            <svg
              viewBox="0 0 60 50"
              className="h-3 w-auto shrink-0 mr-1"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              {/* Left speed lines for bag */}
              <line x1="4" y1="23" x2="22" y2="23" stroke="#00b140" strokeWidth="3.2" strokeLinecap="round" />
              <line x1="1" y1="29" x2="19" y2="29" stroke="#00b140" strokeWidth="3.2" strokeLinecap="round" />
              <line x1="6" y1="35" x2="21" y2="35" stroke="#00b140" strokeWidth="3.2" strokeLinecap="round" />

              {/* Clean upright bag container */}
              {/* Bag handle */}
              <path
                d="M36 18 C36 13.5 38.5 11 42 11 C45.5 11 48 13.5 48 18"
                stroke="#00b140"
                strokeWidth="3.2"
                strokeLinecap="round"
              />
              {/* Bag base */}
              <path
                d="M31 18 H53 L54.5 41 C54.5 42.5 53 44 51.5 44 H32.5 C31 44 29.5 42.5 29.5 41 L31 18 Z"
                fill="#00b140"
              />
            </svg>
            <span className={`text-[9px] font-black tracking-widest uppercase ${lightMode ? 'text-gray-300' : 'text-[#00b140] dark:text-emerald-400'}`}>
              Delivery App
            </span>
          </div>
        </div>
      )}
    </div>
  )
}

