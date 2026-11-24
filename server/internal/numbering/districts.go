package numbering

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

type District struct {
	Code      int    `json:"code"`
	NameEn    string `json:"name_en"`
	NameBn    string `json:"name_bn"`
	Division  string `json:"division"`
}

var Districts = map[int]District{
	1:  {Code: 1, NameEn: "Dhaka", NameBn: "ঢাকা", Division: "Dhaka"},
	2:  {Code: 2, NameEn: "Narsingdi", NameBn: "নরসিংদী", Division: "Dhaka"},
	3:  {Code: 3, NameEn: "Brahmanbaria", NameBn: "ব্রাহ্মণবাড়িয়া", Division: "Chattogram"},
	4:  {Code: 4, NameEn: "Kishoreganj", NameBn: "কিশোরগঞ্জ", Division: "Dhaka"},
	5:  {Code: 5, NameEn: "Gazipur", NameBn: "গাজীপুর", Division: "Dhaka"},
	6:  {Code: 6, NameEn: "Manikganj", NameBn: "মানিকগঞ্জ", Division: "Dhaka"},
	7:  {Code: 7, NameEn: "Munshiganj", NameBn: "মুন্সিগঞ্জ", Division: "Dhaka"},
	8:  {Code: 8, NameEn: "Narayanganj", NameBn: "নারায়ণগঞ্জ", Division: "Dhaka"},
	9:  {Code: 9, NameEn: "Tangail", NameBn: "টাঙ্গাইল", Division: "Dhaka"},
	10: {Code: 10, NameEn: "Faridpur", NameBn: "ফরিদপুর", Division: "Dhaka"},
	11: {Code: 11, NameEn: "Gopalganj", NameBn: "গোপালগঞ্জ", Division: "Dhaka"},
	12: {Code: 12, NameEn: "Madaripur", NameBn: "মাদারীপুর", Division: "Dhaka"},
	13: {Code: 13, NameEn: "Rajbari", NameBn: "রাজবাড়ী", Division: "Dhaka"},
	14: {Code: 14, NameEn: "Shariatpur", NameBn: "শরীয়তপুর", Division: "Dhaka"},
	15: {Code: 15, NameEn: "Chattogram", NameBn: "চট্টগ্রাম", Division: "Chattogram"},
	16: {Code: 16, NameEn: "Cumilla", NameBn: "কুমিল্লা", Division: "Chattogram"},
	17: {Code: 17, NameEn: "Chandpur", NameBn: "চাঁদপুর", Division: "Chattogram"},
	18: {Code: 18, NameEn: "Cox's Bazar", NameBn: "কক্সবাজার", Division: "Chattogram"},
	19: {Code: 19, NameEn: "Feni", NameBn: "ফেনী", Division: "Chattogram"},
	20: {Code: 20, NameEn: "Lakshmipur", NameBn: "লক্ষ্মীপুর", Division: "Chattogram"},
	21: {Code: 21, NameEn: "Noakhali", NameBn: "নোয়াখালী", Division: "Chattogram"},
	22: {Code: 22, NameEn: "Rangamati", NameBn: "রাঙ্গামাটি", Division: "Chattogram"},
	23: {Code: 23, NameEn: "Khagrachhari", NameBn: "খাগড়াছড়ি", Division: "Chattogram"},
	24: {Code: 24, NameEn: "Bandarban", NameBn: "বান্দরবান", Division: "Chattogram"},
	25: {Code: 25, NameEn: "Rajshahi", NameBn: "রাজশাহী", Division: "Rajshahi"},
	26: {Code: 26, NameEn: "Naogaon", NameBn: "নওগাঁ", Division: "Rajshahi"},
	27: {Code: 27, NameEn: "Natore", NameBn: "নাটোর", Division: "Rajshahi"},
	28: {Code: 28, NameEn: "Chapainawabganj", NameBn: "চাঁপাইনবাবগঞ্জ", Division: "Rajshahi"},
	29: {Code: 29, NameEn: "Pabna", NameBn: "পাবনা", Division: "Rajshahi"},
	30: {Code: 30, NameEn: "Bogura", NameBn: "বগুড়া", Division: "Rajshahi"},
	31: {Code: 31, NameEn: "Joypurhat", NameBn: "জয়পুরহাট", Division: "Rajshahi"},
	32: {Code: 32, NameEn: "Sirajganj", NameBn: "সিরাজগঞ্জ", Division: "Rajshahi"},
	33: {Code: 33, NameEn: "Khulna", NameBn: "খুলনা", Division: "Khulna"},
	34: {Code: 34, NameEn: "Bagerhat", NameBn: "বাগেরহাট", Division: "Khulna"},
	35: {Code: 35, NameEn: "Satkhira", NameBn: "সাতক্ষীরা", Division: "Khulna"},
	36: {Code: 36, NameEn: "Jessore", NameBn: "যশোর", Division: "Khulna"},
	37: {Code: 37, NameEn: "Magura", NameBn: "মাগুরা", Division: "Khulna"},
	38: {Code: 38, NameEn: "Narail", NameBn: "নড়াইল", Division: "Khulna"},
	39: {Code: 39, NameEn: "Jhenaidah", NameBn: "ঝিনাইদহ", Division: "Khulna"},
	40: {Code: 40, NameEn: "Kushtia", NameBn: "কুষ্টিয়া", Division: "Khulna"},
	41: {Code: 41, NameEn: "Chuadanga", NameBn: "চুয়াডাঙ্গা", Division: "Khulna"},
	42: {Code: 42, NameEn: "Meherpur", NameBn: "মেহেরপুর", Division: "Khulna"},
	43: {Code: 43, NameEn: "Barishal", NameBn: "বরিশাল", Division: "Barishal"},
	44: {Code: 44, NameEn: "Patuakhali", NameBn: "পটুয়াখালী", Division: "Barishal"},
	45: {Code: 45, NameEn: "Bhola", NameBn: "ভোলা", Division: "Barishal"},
	46: {Code: 46, NameEn: "Pirojpur", NameBn: "পিরোজপুর", Division: "Barishal"},
	47: {Code: 47, NameEn: "Jhalokati", NameBn: "ঝালকাঠি", Division: "Barishal"},
	48: {Code: 48, NameEn: "Barguna", NameBn: "বরগুনা", Division: "Barishal"},
	49: {Code: 49, NameEn: "Sylhet", NameBn: "সিলেট", Division: "Sylhet"},
	50: {Code: 50, NameEn: "Moulvibazar", NameBn: "মৌলভীবাজার", Division: "Sylhet"},
	51: {Code: 51, NameEn: "Habiganj", NameBn: "হবিগঞ্জ", Division: "Sylhet"},
	52: {Code: 52, NameEn: "Sunamganj", NameBn: "সুনামগঞ্জ", Division: "Sylhet"},
	53: {Code: 53, NameEn: "Rangpur", NameBn: "রংপুর", Division: "Rangpur"},
	54: {Code: 54, NameEn: "Dinajpur", NameBn: "দিনাজপুর", Division: "Rangpur"},
	55: {Code: 55, NameEn: "Thakurgaon", NameBn: "ঠাকুরগাঁও", Division: "Rangpur"},
	56: {Code: 56, NameEn: "Panchagarh", NameBn: "পঞ্চগড়", Division: "Rangpur"},
	57: {Code: 57, NameEn: "Nilphamari", NameBn: "নীলফামারী", Division: "Rangpur"},
	58: {Code: 58, NameEn: "Lalmonirhat", NameBn: "লালমনিরহাট", Division: "Rangpur"},
	59: {Code: 59, NameEn: "Kurigram", NameBn: "কুড়িগ্রাম", Division: "Rangpur"},
	60: {Code: 60, NameEn: "Gaibandha", NameBn: "গাইবান্ধা", Division: "Rangpur"},
	61: {Code: 61, NameEn: "Mymensingh", NameBn: "ময়মনসিংহ", Division: "Mymensingh"},
	62: {Code: 62, NameEn: "Jamalpur", NameBn: "জামালপুর", Division: "Mymensingh"},
	63: {Code: 63, NameEn: "Sherpur", NameBn: "শেরপুর", Division: "Mymensingh"},
	64: {Code: 64, NameEn: "Netrokona", NameBn: "নেত্রকোনা", Division: "Mymensingh"},
}

// Generate7DigitID produces a random 7-digit numeric string (1000000 - 9999999)
func Generate7DigitID() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(9000000))
	if err != nil {
		return "", err
	}
	id := n.Int64() + 1000000
	return fmt.Sprintf("%07d", id), nil
}

// FormatIntraComNumber formats the district code and 7-digit ID into standard +Code-ID format
func FormatIntraComNumber(districtCode int, userNumber string) string {
	return fmt.Sprintf("+%d-%s", districtCode, userNumber)
}
