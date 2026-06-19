const products = [
  {
    "id": "cmqheze1i000004kzr09pr2dn",
    "name": "Mineral Water",
    "slug": "mineral-water",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781661033/btu7qxiaqj1w5ww7fhoc.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 18,
    "discount": 10,
    "unit": "1 L",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqheu2kc000004kzr9v5aq82",
    "name": "Maaza",
    "slug": "maaza",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660787/drpdaxipg1dfg6ki4g02.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 50,
    "price": 49,
    "discount": 2,
    "unit": "1 L",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqheox3i000504kz4kdyx8cs",
    "name": "Campa",
    "slug": "campa",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660510/bes4tn5mx8dfwidmk4jf.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "500 ml",
    "stock": 150,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": [
      {"mrp": 20, "name": "Lemon", "price": 20, "stock": 50},
      {"mrp": 20, "name": "Orange", "price": 20, "stock": 50},
      {"mrp": 20, "name": "Cola", "price": 20, "stock": 50}
    ]
  },
  {
    "id": "cmqhemxbd000404kzqufrnq4r",
    "name": "Pepsi ",
    "slug": "pepsi",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660454/iydg6e5clirhx1r3ybof.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "400 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhem3yg000304kza2tpu1ba",
    "name": "Dew",
    "slug": "dew-1",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660395/k9dld62d7cvyv9u0sc30.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "400 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhek9qp000104kztd30hwjf",
    "name": "Sprite",
    "slug": "sprite-2",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660341/nnd3pxq98hplswr4swy0.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "400 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqheikt6000104jsre8zjolh",
    "name": "Thumsup",
    "slug": "thumsup-1",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660249/a1vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "400 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe8e1i000204kzn7a5rs4n",
    "name": "Hell",
    "slug": "hell",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659976/ykyvx8gsczwhx9f298n3.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 60,
    "price": 50,
    "discount": 17,
    "unit": "250 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe7hqy000104kzdhz09g0l",
    "name": "Energy Campa",
    "slug": "energy-campa",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659926/w2x2pwsmdqwvn0mvyc0m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 10,
    "price": 10,
    "discount": 0,
    "unit": "250 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe6s0o000004kzr37pdot9",
    "name": "Diet Coke",
    "slug": "diet-coke",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659871/h1vqsqwvywndx1p2z9mj.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 40,
    "price": 38,
    "discount": 5,
    "unit": "300 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe4zgm000104jsipjqhmk0",
    "name": "Sprite",
    "slug": "sprite-1",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659809/a2vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 40,
    "price": 38,
    "discount": 5,
    "unit": "750 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe3k9j000004iia798vnud",
    "name": "Thumsup",
    "slug": "thumsup-2",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659754/k1vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 40,
    "price": 38,
    "discount": 5,
    "unit": "750 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhe2f60000004js1qdbd61j",
    "name": "Coca Cola ",
    "slug": "coca-cola",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781659695/d1vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 40,
    "price": 38,
    "discount": 5,
    "unit": "750 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhehn8z000004jsfdy91wjy",
    "name": "Sprite ",
    "slug": "sprite",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660193/s1vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "250 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhel3ac000204kz1v3ww33u",
    "name": "Dew",
    "slug": "dew",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660132/a9dld62d7cvyv9u0sc30.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "250 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  },
  {
    "id": "cmqhejcye000004kz09h2u7bt",
    "name": "Thumsup",
    "slug": "thumsup",
    "description": "",
    "imageUrl": "https://res.cloudinary.com/dvcsjvpbg/image/upload/v1781660081/t1vshmdq9mvywquvsd6m.png",
    "categoryId": "cmqgzqfz20008vkidoycqg5u2",
    "mrp": 20,
    "price": 20,
    "discount": 0,
    "unit": "250 ml",
    "stock": 50,
    "isAvailable": true,
    "tags": ["beverages"],
    "minStock": 10,
    "variants": null
  }
];

const categorySlug = 'beverages';
const activeSubcategoryId = 'all';
const vegFilter = 'all';
const searchQuery = '';
const sort = 'popularity';

// 1. Compute maxPriceOfCategory
const maxPriceOfCategory = products.length === 0 ? 1000 : Math.max(...products.map((p) => p.price));
console.log('maxPriceOfCategory computed:', maxPriceOfCategory);

// 2. Set maxPrice
const maxPrice = maxPriceOfCategory; // simulation of useEffect update

// 3. Process products
let result = [...products];

// Subcategory filter simulation
const filterAll = () => true;
result = result.filter(filterAll);
console.log('After subcategory all filter:', result.length);

// Veg filter simulation
console.log('After veg filter:', result.length);

// Price Limit filter simulation
result = result.filter((p) => p.price <= maxPrice);
console.log('After price filter (<= ' + maxPrice + '):', result.length);

console.log('Final processed products count:', result.length);
